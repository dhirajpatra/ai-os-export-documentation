"""
TradeOS — Database Connection Pool  (core/db/__init__.py)
==========================================================
Raw asyncpg pool — matches the postgresql+asyncpg:// URL in Settings,
but asyncpg itself takes a plain postgres:// DSN (no +asyncpg prefix).

Public API
----------
  await init_pool()          — open pool, called once in lifespan startup
  await close_pool()         — drain pool, called in lifespan shutdown
  get_pool() -> Pool         — returns the live pool (raises if not init'd)
  get_db()                   — FastAPI Depends() that yields a Connection
                               acquired from the pool

Seed data
---------
  await ensure_seed_data(pool) — idempotent: inserts the demo org + admin
                                 user if they do not already exist.
                                 Uses the fixed UUIDs that the rest of the
                                 codebase hardcodes in get_org_context().
"""

from __future__ import annotations

import os
import asyncpg

# ── Fixed seed UUIDs — must match get_org_context() in main.py ──────────────
SEED_ORG_ID   = "00000000-0000-0000-0000-000000000001"
SEED_USER_ID  = "00000000-0000-0000-0000-000000000002"

_pool: asyncpg.Pool | None = None


def _build_dsn() -> str:
    """
    Build a plain postgres:// DSN from env.
    Settings.DATABASE_URL uses postgresql+asyncpg:// (SQLAlchemy style) —
    asyncpg.create_pool() does not understand that prefix, so we normalise.
    """
    url = os.getenv(
        "DATABASE_URL",
        (
            f"postgresql+asyncpg://"
            f"{os.getenv('POSTGRES_USER','tradeos')}:"
            f"{os.getenv('POSTGRES_PASSWORD','tradeos')}@"
            f"{os.getenv('POSTGRES_HOST','postgres')}:"
            f"{os.getenv('POSTGRES_PORT','5432')}/"
            f"{os.getenv('POSTGRES_DB','tradeos')}"
        ),
    )
    # Strip SQLAlchemy dialect prefix if present
    return url.replace("postgresql+asyncpg://", "postgresql://", 1)


async def init_pool() -> asyncpg.Pool:
    """Open the connection pool. Call once at startup."""
    global _pool
    dsn = _build_dsn()
    _pool = await asyncpg.create_pool(
        dsn=dsn,
        min_size=2,
        max_size=10,
        command_timeout=30,
    )
    print(f"✅ DB pool opened — {os.getenv('POSTGRES_HOST','postgres')}:"
          f"{os.getenv('POSTGRES_PORT','5432')}/"
          f"{os.getenv('POSTGRES_DB','tradeos')}")
    await ensure_seed_data(_pool)
    return _pool


async def close_pool():
    """Drain the pool gracefully. Call on shutdown."""
    global _pool
    if _pool:
        await _pool.close()
        _pool = None
        print("🛑 DB pool closed")


def get_pool() -> asyncpg.Pool:
    """Return the live pool. Raises RuntimeError if init_pool() was not called."""
    if _pool is None:
        raise RuntimeError("DB pool is not initialised. Was init_pool() called in lifespan?")
    return _pool


async def get_db():
    """
    FastAPI dependency — yields an asyncpg Connection from the pool.

    Usage:
        @app.get("/example")
        async def handler(db: asyncpg.Connection = Depends(get_db)):
            row = await db.fetchrow("SELECT ...")
    """
    pool = get_pool()
    async with pool.acquire() as conn:
        yield conn


# ── Seed data ────────────────────────────────────────────────────────────────

async def ensure_seed_data(pool: asyncpg.Pool):
    """
    Idempotent bootstrap: insert the demo org and admin user if missing.
    Safe to call on every startup — uses INSERT … ON CONFLICT DO NOTHING.
    """
    async with pool.acquire() as conn:
        # 1 — Demo organisation
        await conn.execute(
            """
            INSERT INTO organizations (
                id, name, slug, country, plan, timezone, default_currency
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            ON CONFLICT (id) DO NOTHING
            """,
            SEED_ORG_ID,
            "Agro Exports India Pvt Ltd",
            "agro-exports-india",
            "IN",
            "growth",
            "Asia/Kolkata",
            "INR",
        )

        # 2 — Demo admin user (password_hash intentionally NULL for seed)
        await conn.execute(
            """
            INSERT INTO users (
                id, org_id, email, name, role
            )
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT (org_id, email) DO NOTHING
            """,
            SEED_USER_ID,
            SEED_ORG_ID,
            "admin@agro-exports.example",
            "Demo Admin",
            "admin",
        )

    print(f"✅ Seed data verified — org={SEED_ORG_ID}  user={SEED_USER_ID}")
