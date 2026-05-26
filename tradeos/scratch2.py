import asyncio
import os
import json
import asyncpg
from dotenv import load_dotenv

load_dotenv()

async def main():
    db_url = os.getenv("DATABASE_URL")
    
    # asyncpg might fail with `channel_binding=require` depending on version, so we strip it
    if "&channel_binding=require" in db_url:
        db_url = db_url.replace("&channel_binding=require", "")
        
    conn = await asyncpg.connect(db_url)
    
    print("--- LATEST WORKFLOWS ---")
    rows = await conn.fetch("SELECT id, context FROM workflows ORDER BY created_at DESC LIMIT 1")
    for row in rows:
        print(f"Workflow ID: {row['id']}")
        try:
            ctx = json.loads(row["context"])
            print("raw_text sample:", ctx.get("raw_text", "")[:500])
        except Exception as e:
            print("Error parsing context:", e)
            
    print("\n--- LATEST ORDERS ---")
    rows = await conn.fetch("SELECT id, po_raw_text FROM orders ORDER BY created_at DESC LIMIT 1")
    for row in rows:
        print(f"Order ID: {row['id']}")
        print("PO Raw Text:", str(row["po_raw_text"])[:500])

    await conn.close()

asyncio.run(main())
