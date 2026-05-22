"""
TradeOS — Knowledge Base  (core/knowledge_base.py)
===================================================
Local RAG for handling non-PO WhatsApp messages:
  greetings, queries, complaints, general trade questions.

Embedding model : sentence-transformers/all-MiniLM-L6-v2
                  (already in requirements.txt, runs on CPU, 384-dim)
Storage         : agent_memory table (memory_type='country_rule',
                  scope_type='org') — no schema changes needed
Retrieval       : cosine similarity via pgvector
Answering       : Ollama qwen2.5:3b with retrieved context

Public API
----------
  await LocalEmbedder.embed(text)          → list[float]  (384-dim)
  await KnowledgeBase.seed(pool, org_id)   → seeds FAQ on startup (idempotent)
  await KnowledgeBase.search(pool, org_id, query, top_k) → list[str]  (context chunks)
  await KnowledgeBase.answer(pool, org_id, question, sender_name) → str  (WA reply)
"""

from __future__ import annotations

import asyncio
import json
import os
from functools import lru_cache
from typing import Any

import asyncpg
import httpx


# ─────────────────────────────────────────────
# LOCAL EMBEDDER  (sentence-transformers, CPU)
# ─────────────────────────────────────────────

class LocalEmbedder:
    """
    Wraps sentence-transformers/all-MiniLM-L6-v2.
    Model is loaded once and cached for the process lifetime.
    Thread-safe: SentenceTransformer.encode() releases the GIL.
    Runs encode() in a thread pool so it doesn't block the event loop.
    """

    _model = None
    _lock  = asyncio.Lock()

    @classmethod
    async def _load(cls):
        async with cls._lock:
            if cls._model is None:
                # Import here so startup isn't blocked if torch is slow to init
                from sentence_transformers import SentenceTransformer
                cls._model = SentenceTransformer("all-MiniLM-L6-v2")
                print("[Embedder] all-MiniLM-L6-v2 loaded (384-dim, CPU)")

    @classmethod
    async def embed(cls, text: str) -> list[float]:
        """Embed a single string. Returns a 384-dimensional float list."""
        await cls._load()
        loop = asyncio.get_event_loop()
        # Run in thread pool — encode() is CPU-bound
        embedding = await loop.run_in_executor(
            None,
            lambda: cls._model.encode(text, normalize_embeddings=True).tolist()
        )
        return embedding

    @classmethod
    async def embed_batch(cls, texts: list[str]) -> list[list[float]]:
        """Embed multiple strings in one call (faster than looping)."""
        await cls._load()
        loop = asyncio.get_event_loop()
        embeddings = await loop.run_in_executor(
            None,
            lambda: cls._model.encode(texts, normalize_embeddings=True).tolist()
        )
        return embeddings


# ─────────────────────────────────────────────
# FAQ CHUNKS  (parsed from TradeOS_FAQ_Knowledge.md)
# ─────────────────────────────────────────────

# Each entry: (key, question, answer)
# key must be unique per org — used for ON CONFLICT DO NOTHING idempotent seed
FAQ_CHUNKS: list[tuple[str, str, str]] = [
    (
        "faq_products",
        "What products do you export?",
        "We export seafood products, frozen shrimp, spices, coir products, cashew products, "
        "agricultural commodities, FMCG products, and engineering goods."
    ),
    (
        "faq_payment_terms",
        "What payment terms do you offer?",
        "We support advance payment, Letter of Credit (LC), Documents Against Payment (DP), "
        "and open account for trusted buyers. For new buyers, LC or partial advance payment is preferred."
    ),
    (
        "faq_ports",
        "Which ports do you use for export?",
        "Common ports of loading include Cochin Port, Chennai Port, Nhava Sheva (JNPT), "
        "Tuticorin Port, and Vizag Port. Port selection depends on cargo type, destination, "
        "and shipping schedules."
    ),
    (
        "faq_lead_times",
        "What are your standard delivery lead times?",
        "Typical lead times: domestic procurement 2–7 days, processing & packaging 1–5 days, "
        "documentation 1–2 days, customs clearance 1–3 days. Shipping transit depends on "
        "destination country, freight mode, and shipping line schedules."
    ),
    (
        "faq_countries",
        "Which countries do you export to?",
        "Primary export regions include UAE, Saudi Arabia, Qatar, Oman, Kuwait, Europe, "
        "United States, and Southeast Asia."
    ),
    (
        "faq_certifications",
        "What certifications do you maintain?",
        "Certifications include FSSAI, APEDA, MPEDA, HACCP, ISO certifications, "
        "Halal certifications, and Phytosanitary certifications. Requirements vary by "
        "product category and importing country."
    ),
    (
        "faq_moq",
        "What is your minimum order quantity?",
        "MOQ depends on product category, packaging type, shipping economics, and destination market. "
        "TradeOS AI automatically validates MOQ against quotation workflows."
    ),
    (
        "faq_reefer",
        "Do you support reefer or cold-chain shipments?",
        "Yes. Cold-chain logistics are supported for seafood, frozen foods, and temperature-sensitive "
        "cargo, including reefer container coordination, cold storage handling, and temperature "
        "compliance monitoring."
    ),
    (
        "faq_incoterms",
        "Which Incoterms do you support?",
        "Supported Incoterms: FOB, CIF, CFR, EXW, and DDP for select markets."
    ),
    (
        "faq_new_buyers",
        "What are your policies for new buyers?",
        "New buyers require KYC verification. LC or advance payment is preferred. "
        "Buyer risk screening and country sanctions checks are applied."
    ),
    (
        "faq_documents",
        "What export documents do you generate?",
        "TradeOS generates Commercial Invoice, Packing List, Bill of Lading, Shipping Bill, "
        "Certificate of Origin, Insurance Certificate, LC document sets, and export declarations."
    ),
    (
        "faq_compliance",
        "Does TradeOS support customs compliance?",
        "Yes. TradeOS validates against DGFT rules, ICEGATE workflows, UAE customs requirements, "
        "sanctions screening, and restricted goods policies."
    ),
    (
        "faq_pdf_ocr",
        "Can TradeOS process PDFs and scanned documents?",
        "Yes. Supported formats include PDFs, scanned invoices, packing lists, BL copies, "
        "LC documents, and handwritten notes (limited support). OCR and AI extraction pipelines "
        "process documents automatically."
    ),
    (
        "faq_tracking",
        "Can shipments be tracked automatically?",
        "Yes. TradeOS supports container tracking, shipment milestones, ETA monitoring, "
        "customs clearance status, and customer notifications."
    ),
    (
        "faq_lc_workflow",
        "Can TradeOS manage LC workflows?",
        "Yes. TradeOS can validate LC conditions, compare invoice consistency, monitor "
        "discrepancies, and assist with bank documentation."
    ),
    (
        "faq_agents",
        "What AI agents exist in TradeOS?",
        "Core agents include: Documentation Agent, Compliance Agent, Logistics Agent, "
        "Finance Agent, Communication Agent, and Supervisor Agent."
    ),
    (
        "faq_autonomous",
        "Is TradeOS fully autonomous?",
        "No. TradeOS uses AI automation with human approval checkpoints, audit trails, "
        "and escalation workflows. Critical decisions still require human review."
    ),
    (
        "faq_multilingual",
        "Does TradeOS support multilingual workflows?",
        "Yes. Supported languages include English, Arabic, Hindi, and Malayalam."
    ),
    (
        "faq_pricing",
        "What are your typical price ranges?",
        "Pricing depends on product grade, quantity, destination country, Incoterms, "
        "seasonality, and freight cost. TradeOS AI generates indicative pricing ranges "
        "based on historical quotations and current market conditions."
    ),
    (
        "faq_erp",
        "Will TradeOS support ERP integrations?",
        "Yes. Planned integrations include Tally, Zoho Books, Odoo, and SAP Business One."
    ),
]


# ─────────────────────────────────────────────
# KNOWLEDGE BASE
# ─────────────────────────────────────────────

class KnowledgeBase:
    """
    Manages FAQ storage and retrieval from agent_memory table.
    All FAQ entries are stored as:
      agent_name  = 'faq_agent'
      memory_type = 'country_rule'   (closest allowed type — no schema change)
      scope_type  = 'org'
      key         = faq_<topic>      (e.g. 'faq_products')
      value       = {"question": str, "answer": str}
    """

    AGENT_NAME   = "faq_agent"
    MEMORY_TYPE  = "country_rule"
    SCOPE_TYPE   = "org"

    @classmethod
    async def seed(cls, pool: asyncpg.Pool, org_id: str):
        """
        Idempotent: insert all FAQ chunks with embeddings on startup.
        Safely checks for existing records before handling insertions to bypass
        schema constraint format variations.
        """
        print(f"[KB] seeding {len(FAQ_CHUNKS)} FAQ chunks for org {org_id}…")

        # Embed all questions in one batch call (faster than one-by-one)
        questions  = [q for _, q, _ in FAQ_CHUNKS]
        embeddings = await LocalEmbedder.embed_batch(questions)

        async with pool.acquire() as db:
            # Step 1: Query existing keys for this org to guarantee idempotency
            existing_rows = await db.fetch(
                """
                SELECT key FROM agent_memory 
                WHERE org_id = $1 AND agent_name = $2 AND memory_type = $3 AND scope_type = $4
                """,
                org_id, cls.AGENT_NAME, cls.MEMORY_TYPE, cls.SCOPE_TYPE
            )
            existing_keys = {row["key"] for row in existing_rows}

            inserted = 0
            # Step 2: Only insert chunks that are completely missing
            for (key, question, answer), embedding in zip(FAQ_CHUNKS, embeddings):
                if key in existing_keys:
                    continue

                await db.execute(
                    """
                    INSERT INTO agent_memory (
                        org_id, agent_name, memory_type,
                        scope_type, key, value,
                        confidence, source, embedding
                    )
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::vector)
                    """,
                    org_id,
                    cls.AGENT_NAME,
                    cls.MEMORY_TYPE,
                    cls.SCOPE_TYPE,
                    key,
                    json.dumps({"question": question, "answer": answer}),
                    95.0,
                    "seed",
                    json.dumps(embedding),   # pgvector accepts JSON array string
                )
                inserted += 1

        print(f"[KB] seeded {inserted} new chunks ({len(FAQ_CHUNKS) - inserted} already existed)")

    @classmethod
    async def search(
        cls,
        pool:    asyncpg.Pool,
        org_id:  str,
        query:   str,
        top_k:   int = 3,
    ) -> list[str]:
        """
        Embed the query and retrieve top_k most similar FAQ answers via pgvector.
        Returns a list of answer strings ready to pass as context to the LLM.
        """
        query_embedding = await LocalEmbedder.embed(query)

        async with pool.acquire() as db:
            rows = await db.fetch(
                """
                SELECT value,
                       1 - (embedding <=> $1::vector) AS similarity
                FROM   agent_memory
                WHERE  org_id      = $2
                  AND  agent_name  = $3
                  AND  memory_type = $4
                  AND  scope_type  = $5
                  AND  embedding   IS NOT NULL
                ORDER  BY embedding <=> $1::vector
                LIMIT  $6
                """,
                json.dumps(query_embedding),
                org_id,
                cls.AGENT_NAME,
                cls.MEMORY_TYPE,
                cls.SCOPE_TYPE,
                top_k,
            )

        results = []
        for row in rows:
            data = json.loads(row["value"])
            similarity = float(row["similarity"])
            if similarity > 0.25:   # minimum relevance threshold
                results.append(f"Q: {data['question']}\nA: {data['answer']}")

        return results

    @classmethod
    async def answer(
        cls,
        pool:         asyncpg.Pool,
        org_id:       str,
        question:     str,
        intent:       str = "query",   # "query" | "complaint" | "greeting"
        sender_name:  str = "",
    ) -> str:
        """
        Full RAG pipeline:
          1. Retrieve relevant FAQ chunks from DB
          2. Build context-aware prompt
          3. Call Ollama to generate reply
          4. Return ready-to-send WhatsApp message string

        Falls back to a polite hardcoded reply if Ollama times out.
        """
        ollama_base = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434").rstrip("/")
        ollama_model = os.getenv("OLLAMA_MODEL", "qwen2.5:3b")
        timeout = int(os.getenv("LOCAL_LLM_TIMEOUT_S", "12"))

        # ── 1. Retrieve relevant context ────────────────────────
        context_chunks: list[str] = []
        if intent in ("query", "greeting"):
            try:
                context_chunks = await cls.search(pool, org_id, question, top_k=3)
            except Exception as exc:
                print(f"[KB] search failed: {exc}")

        context_block = (
            "\n\n".join(context_chunks)
            if context_chunks
            else "No specific FAQ found — use your general knowledge about the company."
        )

        # ── 2. Build system prompt based on intent ───────────────
        greeting_part = f"The customer's name is {sender_name}. " if sender_name else ""

        if intent == "complaint":
            system = (
                "You are a professional customer service representative for Agro Exports India Pvt Ltd, "
                "an international trade export company. "
                f"{greeting_part}"
                "The customer has expressed dissatisfaction. "
                "Respond with genuine empathy, acknowledge their concern, apologize sincerely, "
                "and assure them that the team will follow up within 24 hours. "
                "Do NOT make specific promises about refunds or replacements. "
                "Keep it under 5 lines. WhatsApp format."
            )
            user_prompt = question

        elif intent == "greeting":
            system = (
                "You are a friendly assistant for Agro Exports India Pvt Ltd, "
                "an international trade export company. "
                f"{greeting_part}"
                "The customer has sent a greeting or casual message. "
                "Respond warmly and briefly. Mention you can help with export orders, "
                "shipment queries, and trade documents. Under 4 lines. WhatsApp format."
            )
            user_prompt = question

        else:  # query
            system = (
                "You are a knowledgeable assistant for Agro Exports India Pvt Ltd, "
                "an international trade export company. "
                f"{greeting_part}"
                "Answer the customer's question using the FAQ context below. "
                "If the context doesn't cover the question, give a helpful general answer "
                "and offer to connect them with the team. "
                "Be concise — maximum 6 lines. WhatsApp format. No bullet overload.\n\n"
                f"FAQ Context:\n{context_block}"
            )
            user_prompt = question

        # ── 3. Call Ollama ───────────────────────────────────────
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                resp = await client.post(
                    f"{ollama_base}/api/chat",
                    json={
                        "model":   ollama_model,
                        "messages": [
                            {"role": "system", "content": system},
                            {"role": "user",   "content": user_prompt},
                        ],
                        "stream":  False,
                        "options": {"num_predict": 250, "temperature": 0.3},
                    },
                )
                resp.raise_for_status()
                return resp.json()["message"]["content"].strip()

        except Exception as exc:
            print(f"[KB] Ollama answer failed: {exc}")

            # ── 4. Hardcoded fallbacks ───────────────────────────
            if intent == "complaint":
                return (
                    "We sincerely apologize for the inconvenience. "
                    "Your concern has been noted and our team will contact you within 24 hours. "
                    "Thank you for your patience."
                )
            elif intent == "greeting":
                return (
                    "Hello! 👋 Welcome to Agro Exports India. "
                    "I can help you with export orders, shipment queries, and trade documents. "
                    "How can I assist you today?"
                )
            else:
                return (
                    "Thank you for your question. "
                    "Our team will get back to you with the information shortly. "
                    "For urgent queries, please contact us directly."
                )
