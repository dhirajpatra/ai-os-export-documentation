# core/mcp_usage.py
import uuid
from core.db import get_pool

async def record_mcp_call(
    org_id: uuid.UUID,
    service: str,
    action: str,
    request_ms: int = 0,
    tokens_used: int = 0,
    cost_usd: float = 0.0,
    status: str = "ok",
) -> None:
    """Non-fatal — billing log failure must never break a service call."""
    try:
        pool = get_pool()
        async with pool.acquire() as db:
            await db.execute(
                """
                INSERT INTO mcp_usage_log
                    (org_id, service, action, request_ms, tokens_used, cost_usd, status)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                """,
                org_id, service, action, request_ms, tokens_used, cost_usd, status,
            )
            # Upsert monthly billing counter
            await db.execute(
                """
                INSERT INTO mcp_billing (org_id, period_start, period_end, plan, calls_used, calls_limit)
                VALUES (
                    $1,
                    date_trunc('month', now())::date,
                    (date_trunc('month', now()) + interval '1 month - 1 day')::date,
                    (SELECT plan FROM organizations WHERE id = $1),
                    1,
                    (SELECT CASE plan
                        WHEN 'starter'    THEN 100
                        WHEN 'growth'     THEN 1000
                        WHEN 'enterprise' THEN -1
                    END FROM organizations WHERE id = $1)
                )
                ON CONFLICT (org_id, period_start)
                DO UPDATE SET
                    calls_used = mcp_billing.calls_used + 1,
                    cost_usd   = mcp_billing.cost_usd + EXCLUDED.cost_usd
                """,
                org_id,
            )
    except Exception as exc:
        print(f"[mcp_usage] billing log failed (non-fatal): {exc}")