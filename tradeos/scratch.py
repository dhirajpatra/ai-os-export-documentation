import asyncio
import os
import json
from dotenv import load_dotenv

load_dotenv()
# We need to install asyncpg if not present, but it's likely already there
try:
    import asyncpg
except ImportError:
    os.system("pip install asyncpg")
    import asyncpg

async def main():
    db_url = os.getenv("DATABASE_URL", "postgresql://tradeos:tradeos@localhost:5432/tradeos")
    
    conn = await asyncpg.connect(db_url)
    
    # Check latest contacts
    print("--- LATEST CONTACTS ---")
    rows = await conn.fetch("SELECT id, name, created_at FROM contacts ORDER BY created_at DESC LIMIT 3")
    for row in rows:
        print(dict(row))
        
    print("\n--- LATEST APPROVAL REQUESTS (diff_after) ---")
    rows = await conn.fetch("SELECT id, diff_after FROM approval_requests ORDER BY created_at DESC LIMIT 3")
    for row in rows:
        diff = row["diff_after"]
        print(f"Approval ID: {row['id']}")
        try:
            parsed = json.loads(diff)
            print("Importer in Commercial Invoice:")
            ci = parsed.get("commercial_invoice", {})
            print(json.dumps(ci.get("importer", {}), indent=2))
        except:
            print("Could not parse diff_after")

    await conn.close()

asyncio.run(main())
