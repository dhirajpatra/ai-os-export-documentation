# ─────────────────────────────────────────────
# FASTAPI LIFECYCLE MANAGEMENT
# ─────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ────────────────────────────────────────────
    print("🚀 TradeOS API starting — connecting to Redis, DB, Temporal…")

    # ① Redis — init first so SSE bus is ready before any request lands.
    #    Uses REDIS_URL from .env (Upstash rediss:// URL).
    #    Non-fatal: REST APIs keep working even if Redis is down.
    try:
        # in lifespan startup, after DB pool is ready
from core.rules_sync import start_sync_loop
asyncio.create_task(
    start_sync_loop(str(os.getenv("DEFAULT_ORG_ID", "")))
)
        from core.redis_client import init_redis
        await init_redis()
        print("✅ Redis (Upstash) connected — SSE streaming enabled")
    except Exception as exc:
        print(f"⚠️  Redis connection failed: {exc}")
        print("   SSE streaming will be unavailable. Check REDIS_URL in Railway env vars.")

    # ② pypdf availability check (unchanged)
    try:
        from pypdf import PdfReader
        print("✅ pypdf available — text-layer PDF extraction enabled")
    except ImportError:
        print("⚠️  pypdf NOT installed. PDF text extraction will fall back to PaddleOCR.")
        print("   Fix: add 'pypdf' to requirements.txt and rebuild the image.")

    # ③ DB pool (unchanged)
    try:
        from core.db import init_pool, SEED_ORG_ID, get_pool
        await init_pool()
    except Exception as exc:
        print(f"⚠️  DB pool failed to initialise: {exc}")
        print("   Approval/shipment persistence will be unavailable this session.")

    # ④ Knowledge base seed (unchanged)
    try:
        from core.db import get_pool, SEED_ORG_ID
        from core.knowledge_base import KnowledgeBase
        pool = get_pool()
        await KnowledgeBase.seed(pool, SEED_ORG_ID)
    except Exception as exc:
        print(f"⚠️  Knowledge base seed failed: {exc}")
        print("   FAQ/RAG answers will fall back to hardcoded replies.")


    yield

    # ── Shutdown ───────────────────────────────────────────
    # Close Redis first (flush any pending pub/sub)
    try:
        from core.redis_client import close_redis
        await close_redis()
        print("✅ Redis connection closed")
    except Exception:
        pass

    try:
        from core.db import close_pool
        await close_pool()
    except Exception:
        pass

    print("🛑 TradeOS API shutting down…")