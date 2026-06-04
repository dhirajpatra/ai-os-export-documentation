# services/mcp/hs_mcp.py  (future cloud service)
from fastapi import APIRouter, Depends
from core.mcp_auth import verify_mcp_key
from core.mcp_usage import record_mcp_call

router = APIRouter()

@router.post("/mcp/hs/validate")
async def hs_validate(body: HSValidateRequest, org: dict = Depends(verify_mcp_key)):
    import time
    t0 = time.monotonic()

    result = await run_hs_validation(body.items, body.route)

    await record_mcp_call(
        org_id      = org["org_id"],
        service     = "hs_classification",
        action      = "validate",
        request_ms  = int((time.monotonic() - t0) * 1000),
        tokens_used = result.get("tokens_used", 0),
        cost_usd    = result.get("cost_usd", 0.0),
    )
    return result