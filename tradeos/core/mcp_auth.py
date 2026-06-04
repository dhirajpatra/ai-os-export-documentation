# core/mcp_auth.py
import hashlib, os
from fastapi import Header, HTTPException, status
from core.db import get_pool

PLAN_LIMITS = {
    "starter":    100,
    "growth":     1000,
    "enterprise": -1,   # unlimited
}

async def verify_mcp_key(x_tradeos_key: str = Header(...)) -> dict:
    """
    FastAPI dependency for MCP endpoints.
    Validates API key, checks quota, logs usage intent.
    Returns org context dict.
    """
    if not x_tradeos_key:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "MCP API key required")

    key_hash = hashlib.sha256(x_tradeos_key.encode()).hexdigest()
    pool = get_pool()

    async with pool.acquire() as db:
        row = await db.fetchrow(
            """
            SELECT k.org_id, k.is_active, o.plan
            FROM mcp_api_keys k
            JOIN organizations o ON o.id = k.org_id
            WHERE k.key_hash = $1 AND k.environment = 'live'
            """,
            key_hash,
        )

    if not row or not row["is_active"]:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or inactive MCP key")

    # Quota check
    plan   = row["plan"]
    limit  = PLAN_LIMITS.get(plan, 100)
    if limit != -1:
        async with pool.acquire() as db:
            used = await db.fetchval(
                """
                SELECT calls_used FROM mcp_billing
                WHERE org_id = $1
                  AND period_start = date_trunc('month', now())::date
                """,
                row["org_id"],
            )
            if used and used >= limit:
                raise HTTPException(
                    status.HTTP_429_TOO_MANY_REQUESTS,
                    f"Monthly MCP quota exceeded ({limit} calls on {plan} plan)"
                )

    # Update last_used_at async — non-blocking
    async with pool.acquire() as db:
        await db.execute(
            "UPDATE mcp_api_keys SET last_used_at = NOW() WHERE key_hash = $1",
            key_hash,
        )

    return {"org_id": row["org_id"], "plan": plan}