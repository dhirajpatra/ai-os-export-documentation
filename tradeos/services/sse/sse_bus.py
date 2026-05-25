"""
services/sse/sse_bus.py  (Redis Pub/Sub edition)
=================================================
Replaces the in-memory asyncio.Queue version.

Why Redis instead of in-memory queues
--------------------------------------
Railway can run multiple uvicorn workers / replicas. With an in-memory
queue the SSE consumer and the workflow might land on different processes,
so events never reach the browser. Redis Pub/Sub is visible to every
worker on every Railway instance — events published anywhere are received
everywhere.

Architecture
------------
  push_event(workflow_id, step, status, data)
      └─→  PUBLISH  sse:{workflow_id}  JSON-payload

  sse_stream(workflow_id)
      └─→  SUBSCRIBE  sse:{workflow_id}
           └─→  yield SSE messages until __DONE__ sentinel or timeout

  close_channel(workflow_id)
      └─→  PUBLISH  sse:{workflow_id}  {"__done__": true}

Every Railway replica subscribes to the same Redis channel, so it does
not matter which worker handles the HTTP request vs which runs the workflow.

Redis key conventions
---------------------
  Channel:   sse:{workflow_id}          Pub/Sub channel (no persistence)
  Sentinel:  {"__done__": true}         Published by close_channel()
  Heartbeat: {"__heartbeat__": true}    Filtered out — never sent to browser

Usage (unchanged API — drop-in replacement)
-------------------------------------------
    from services.sse.sse_bus import push_event, close_channel, sse_stream

    # In a workflow node:
    await push_event(workflow_id, "po_extraction", "done", {"confidence": 0.92})

    # In the FastAPI SSE route:
    return StreamingResponse(sse_stream(workflow_id), media_type="text/event-stream")
"""

from __future__ import annotations

import asyncio
import json
from datetime import datetime, timezone
from typing import AsyncGenerator

import redis.asyncio as aioredis

# ── Import your existing Redis client ────────────────────────────────────────
# core/redis_client.py already manages the connection pool.
# We use get_redis() which returns an aioredis.Redis instance.
from core.redis_client import get_redis


# ── Channel naming ────────────────────────────────────────────────────────────

def _channel(workflow_id: str) -> str:
    return f"sse:{workflow_id}"


# ── Sentinel values ───────────────────────────────────────────────────────────

_DONE_PAYLOAD      = json.dumps({"__done__": True})
_HEARTBEAT_PAYLOAD = json.dumps({"__heartbeat__": True})


# ── Public API ────────────────────────────────────────────────────────────────

def create_channel(workflow_id: str) -> None:
    """
    No-op with Redis Pub/Sub — channels are created implicitly on first
    PUBLISH. Kept so call sites (routes, workflow) need zero changes.
    """
    pass


async def push_event(
    workflow_id: str,
    step: str,
    status: str,
    data: dict | None = None,
) -> None:
    """
    Publish a workflow step event to all SSE subscribers.
    Safe to call from any Railway instance / worker.
    """
    payload = {
        "workflow_id": workflow_id,
        "step":        step,
        "status":      status,
        "ts":          datetime.now(timezone.utc).isoformat(),
        "data":        data or {},
    }
    try:
        r = get_redis()
        await r.publish(_channel(workflow_id), json.dumps(payload))
    except Exception as exc:
        # Never let a Redis failure crash the workflow
        print(f"[sse_bus] publish failed for {workflow_id}: {exc}")


async def close_channel(workflow_id: str) -> None:
    """
    Signal all SSE subscribers that the workflow is complete.
    Publishes a sentinel so every connected browser tab closes cleanly.
    """
    try:
        r = get_redis()
        await r.publish(_channel(workflow_id), _DONE_PAYLOAD)
    except Exception as exc:
        print(f"[sse_bus] close_channel failed for {workflow_id}: {exc}")


def remove_channel(workflow_id: str) -> None:
    """
    No-op with Redis — channels have no server-side lifecycle to clean up.
    Kept for API compatibility.
    """
    pass


# ── SSE Generator ─────────────────────────────────────────────────────────────

async def sse_stream(
    workflow_id: str,
    timeout_seconds: int = 120,
) -> AsyncGenerator[str, None]:
    """
    Async generator consumed by FastAPI's StreamingResponse.

    Behaviour
    ---------
    - Subscribes to Redis channel  sse:{workflow_id}
    - Yields one SSE message per workflow step event
    - Sends `: heartbeat` comment every 15 s (keeps Railway / proxies alive)
    - Exits when:
        • __DONE__ sentinel is received  (workflow finished)
        • timeout_seconds elapses        (safety valve)
        • The HTTP connection closes     (FastAPI cancels the generator)

    SSE wire format
    ---------------
    retry: 3000\n\n                        ← tells browser to reconnect after 3s
    event: stream_open\ndata: {...}\n\n
    event: po_extraction.running\ndata: {...}\n\n
    ...
    event: workflow_done\ndata: {...}\n\n
    """
    r: aioredis.Redis = get_redis()

    # Each SSE connection needs its own pubsub object (they maintain
    # per-connection subscription state inside aioredis).
    pubsub = r.pubsub()

    try:
        await pubsub.subscribe(_channel(workflow_id))

        # Reconnect hint — browser retries after 3 s on network drop
        yield "retry: 3000\n\n"

        # Immediate acknowledgement so the browser knows it's connected
        yield _fmt_event("stream_open", {"workflow_id": workflow_id})

        deadline = asyncio.get_event_loop().time() + timeout_seconds

        while True:
            remaining = deadline - asyncio.get_event_loop().time()
            if remaining <= 0:
                yield _fmt_event("stream_timeout", {"workflow_id": workflow_id})
                break

            # Poll Redis with a short timeout so we can send heartbeats
            # even when the workflow is slow between steps.
            try:
                message = await asyncio.wait_for(
                    pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0),
                    timeout=min(15.0, remaining),
                )
            except asyncio.TimeoutError:
                # 15 s silence → send heartbeat comment
                yield ": heartbeat\n\n"
                continue

            if message is None:
                # No message yet — short sleep to avoid busy-loop
                await asyncio.sleep(0.05)
                continue

            raw = message.get("data", b"")
            if isinstance(raw, int):
                # Subscription confirmation integer — ignore
                continue

            try:
                payload = json.loads(raw)
            except (json.JSONDecodeError, TypeError):
                continue

            # Sentinel — workflow finished
            if payload.get("__done__"):
                yield _fmt_event("workflow_done", {"workflow_id": workflow_id})
                break

            # Internal heartbeat published by a keep-alive task (if you add one)
            if payload.get("__heartbeat__"):
                yield ": heartbeat\n\n"
                continue

            # Normal step event
            event_type = f"{payload.get('step', 'unknown')}.{payload.get('status', 'event')}"
            yield _fmt_event(event_type, payload)

    except asyncio.CancelledError:
        # Client disconnected — FastAPI cancels the generator; clean up quietly
        pass

    except Exception as exc:
        print(f"[sse_bus] stream error for {workflow_id}: {exc}")
        try:
            yield _fmt_event("stream_error", {"workflow_id": workflow_id, "message": str(exc)})
        except Exception:
            pass

    finally:
        try:
            await pubsub.unsubscribe(_channel(workflow_id))
            await pubsub.close()
        except Exception:
            pass


# ── Helpers ───────────────────────────────────────────────────────────────────

def _fmt_event(event_type: str, data: dict) -> str:
    """Format a single SSE message (RFC 8895)."""
    return f"event: {event_type}\ndata: {json.dumps(data)}\n\n"
