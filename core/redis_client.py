import os
import json
import redis.asyncio as redis
import hashlib

_redis_pool = None

async def get_redis():
    global _redis_pool
    if _redis_pool is None:
        redis_url = os.getenv("REDIS_URL", "redis://redis:6379/0")
        try:
            _redis_pool = redis.from_url(redis_url, decode_responses=True)
            # test connection
            await _redis_pool.ping()
        except Exception as e:
            print(f"[Redis] Failed to connect: {e}")
            _redis_pool = None
    return _redis_pool

async def cache_set(key: str, value: dict | str, ttl_seconds: int = 300):
    """Store AI responses, OCR results, etc. with a 5-min TTL to auto-clean stale data."""
    r = await get_redis()
    if not r:
        return
    if isinstance(value, dict) or isinstance(value, list):
        value = json.dumps(value)
    try:
        await r.set(key, value, ex=ttl_seconds)
    except Exception as e:
        print(f"[Redis] Failed to set {key}: {e}")

async def cache_get(key: str) -> dict | str | None:
    r = await get_redis()
    if not r:
        return None
    try:
        val = await r.get(key)
        if not val:
            return None
        try:
            return json.loads(val)
        except json.JSONDecodeError:
            return val
    except Exception as e:
        print(f"[Redis] Failed to get {key}: {e}")
        return None

def generate_cache_key(prefix: str, content: str) -> str:
    """Generate a stable cache key using SHA-256 for prompts/OCR texts."""
    hashed = hashlib.sha256(content.encode('utf-8')).hexdigest()
    return f"{prefix}:{hashed}"
