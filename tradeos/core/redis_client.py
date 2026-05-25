"""
core/redis_client.py  (Railway-aware, drop-in replacement)
===========================================================
Your existing redis_client.py already exists — this is a patch
showing what get_redis() must look like for sse_bus.py to work.

If your existing file already exposes  get_redis() → aioredis.Redis,
you only need to verify it reads REDIS_URL from env (Railway sets this
automatically when you add a Redis plugin).

Merge what you need from here into your existing core/redis_client.py.
"""

from __future__ import annotations

import os
import redis.asyncio as aioredis

# ── Singleton connection pool ─────────────────────────────────────────────────
# One pool per process — shared across all requests and SSE streams.
# Railway sets REDIS_URL automatically when you attach a Redis plugin:
#   redis://default:<password>@<host>:<port>
_pool: aioredis.ConnectionPool | None = None
_client: aioredis.Redis | None = None


def _build_pool() -> aioredis.ConnectionPool:
    url = os.environ.get("REDIS_URL") or os.environ.get("REDIS_PRIVATE_URL")
    if not url:
        raise RuntimeError(
            "REDIS_URL not set. "
            "In Railway: add a Redis plugin and it appears automatically. "
            "Locally: set REDIS_URL=redis://localhost:6379 in your .env"
        )
    return aioredis.ConnectionPool.from_url(
        url,
        max_connections=20,          # Upstash free tier limit is 100 concurrent
        decode_responses=True,
        socket_timeout=5,
        socket_connect_timeout=5,
        retry_on_timeout=True,
        ssl_cert_reqs=None,
    )


def get_redis() -> aioredis.Redis:
    """
    Return the shared Redis client.
    Call this inside async functions — the pool is initialised lazily
    on first use so it works both in lifespan and in background tasks.
    """
    global _pool, _client
    if _client is None:
        _pool   = _build_pool()
        _client = aioredis.Redis(connection_pool=_pool)
    return _client


async def init_redis() -> None:
    """
    Call from FastAPI lifespan startup to validate the connection early
    and surface config errors before the first request arrives.
    """
    r = get_redis()
    await r.ping()
    print("✅ Redis connected —", os.environ.get("REDIS_URL", "")[:30], "…")


async def close_redis() -> None:
    """Call from FastAPI lifespan shutdown."""
    global _pool, _client
    if _pool:
        await _pool.disconnect()
    _pool   = None
    _client = None


# ── Health check helper ───────────────────────────────────────────────────────

async def redis_ping() -> bool:
    """Returns True if Redis is reachable — use in /health endpoint."""
    try:
        return await get_redis().ping()
    except Exception:
        return False
