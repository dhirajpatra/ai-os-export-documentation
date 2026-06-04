# core/rules_sync.py
"""
Periodic pull of versioned rules bundle from TradeOS cloud.
Runs as a background task on startup (every RULES_SYNC_INTERVAL_H hours).
Non-fatal — if cloud is unreachable, local rules stay active unchanged.
"""
import asyncio, os, hashlib
import httpx
from core.db import get_pool

SYNC_URL           = os.getenv("TRADEOS_CLOUD_URL", "https://cloud.tradeos.in")
SYNC_INTERVAL_H    = int(os.getenv("RULES_SYNC_INTERVAL_H", "6"))
MCP_API_KEY        = os.getenv("TRADEOS_MCP_KEY", "")   # set after key generated


async def fetch_bundle_manifest() -> dict | None:
    """Pull the latest bundle version manifest. Cheap — small JSON."""
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(
                f"{SYNC_URL}/mcp/rules/manifest",
                headers={"X-TradeOS-Key": MCP_API_KEY},
            )
            r.raise_for_status()
            return r.json()
    except Exception as exc:
        print(f"[rules_sync] manifest fetch failed (non-fatal): {exc}")
        return None


async def fetch_bundle(version: str) -> dict | None:
    """Pull full rules bundle for the given version."""
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.get(
                f"{SYNC_URL}/mcp/rules/bundle/{version}",
                headers={"X-TradeOS-Key": MCP_API_KEY},
            )
            r.raise_for_status()
            return r.json()
    except Exception as exc:
        print(f"[rules_sync] bundle fetch failed (non-fatal): {exc}")
        return None


async def apply_bundle(bundle: dict) -> None:
    """
    Write bundle data into local DB tables.
    Each bundle section maps to a table. Only known sections are applied.
    Unknown sections are ignored — forward compatibility.
    """
    pool = get_pool()

    # HS code additions / updates
    hs_updates = bundle.get("hs_codes", [])
    if hs_updates:
        async with pool.acquire() as db:
            for row in hs_updates:
                await db.execute(
                    """
                    INSERT INTO hs_codes (code, description, section, chapter, notes)
                    VALUES ($1, $2, $3, $4, $5)
                    ON CONFLICT (code) DO UPDATE
                        SET description = EXCLUDED.description,
                            notes       = EXCLUDED.notes
                    """,
                    row["code"], row["description"],
                    row.get("section", ""), row.get("chapter", ""),
                    row.get("notes", ""),
                )
        print(f"[rules_sync] applied {len(hs_updates)} HS code updates")

    # Compliance flags (export restrictions, permits, new regulations)
    compliance_updates = bundle.get("compliance_flags", [])
    if compliance_updates:
        async with pool.acquire() as db:
            for row in compliance_updates:
                await db.execute(
                    """
                    INSERT INTO knowledge_entries
                        (category, tags, content, source, valid_from)
                    VALUES ('compliance', $1, $2, $3, NOW())
                    ON CONFLICT DO NOTHING
                    """,
                    row.get("tags", []),
                    row["content"],
                    row.get("source", "tradeos_bundle"),
                )
        print(f"[rules_sync] applied {len(compliance_updates)} compliance flag updates")


async def sync_once(org_id: str) -> None:
    """Pull and apply bundle if a newer version is available."""
    pool     = get_pool()
    manifest = await fetch_bundle_manifest()
    if not manifest:
        return

    latest_version = manifest.get("version", "0.0.0")

    async with pool.acquire() as db:
        current = await db.fetchval(
            "SELECT rules_bundle_version FROM organizations WHERE id = $1",
            org_id,
        )

    if current == latest_version:
        print(f"[rules_sync] already on latest version {latest_version} — skipping")
        return

    print(f"[rules_sync] new version available: {current} → {latest_version}")
    bundle = await fetch_bundle(latest_version)
    if not bundle:
        return

    await apply_bundle(bundle)

    async with pool.acquire() as db:
        await db.execute(
            """
            UPDATE organizations
            SET rules_bundle_version  = $1,
                rules_bundle_synced_at = NOW()
            WHERE id = $2
            """,
            latest_version, org_id,
        )
    print(f"[rules_sync] sync complete — now on version {latest_version}")


async def start_sync_loop(org_id: str) -> None:
    """Background loop — runs forever, pulls every SYNC_INTERVAL_H hours."""
    while True:
        await sync_once(org_id)
        await asyncio.sleep(SYNC_INTERVAL_H * 3600)