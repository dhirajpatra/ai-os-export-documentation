"""
TradeOS — Standalone Isolated Base Agent (services/agents/base.py)
==================================================================
Stateless multi-tenant orchestration baseline hook.
"""

import uuid
from typing import Any
from core.memory import AgentMemoryStore
from core.config import LLMRouter  # Circular dependency clean import

class BaseAgent:
    """All distributed agents inherit from here. Stateless."""
    name: str = "base_agent"

    def __init__(self, org_id: uuid.UUID, db=None, memory_store=None):
        self.org_id = org_id
        self.db = db
        self.memory = memory_store or AgentMemoryStore(org_id=str(org_id))
        
        # FIX: Point directly to the utility class layout, do not instantiate it!
        self.llm = LLMRouter 

    async def _remember(self, key: str, value: Any, memory_type: str,
                        scope_type: str = "org", scope_id: uuid.UUID | None = None,
                        confidence: float = 80.0):
        """Store observation in agent memory layer."""
        await self.memory.remember(
            agent_name=self.name,
            memory_type=memory_type,
            key=key,
            value=value,
            scope_type=scope_type,
            scope_id=str(scope_id) if scope_id else None,
            confidence=confidence
        )

    async def _recall(self, query: str, memory_type: str | None = None, top_k: int = 5) -> list[dict]:
        """Semantic recall from agent memory."""
        memories = await self.memory.search(
            query=query,
            agent_name=self.name,
            memory_type=memory_type,
            top_k=top_k
        )
        return [{"key": m.key, "value": m.value, "confidence": m.confidence} for m in memories]

    def _emit_event(self, event_type: str, payload: dict):
        """Log structured events for tracing/debugging hooks."""
        print(f"[{self.name.upper()} EVENT] {event_type}: {payload}")