import os
import json
import socket

_producer = None

def get_kafka_bootstrap() -> str:
    """Bypassed — Kafka disabled."""
    return "disabled"

async def get_producer():
    """Bypassed — Kafka disabled."""
    return None

async def send_event(topic: str, event_type: str, payload: dict):
    """Bypassed — Kafka disabled."""
    print(f"[KafkaProducer (Disabled)] Bypassed sending event '{event_type}' to '{topic}'")
    return

async def ensure_kafka_topics(topics: list[str]) -> None:
    """Bypassed — Kafka disabled."""
    print(f"[KafkaProducer (Disabled)] Bypassed ensuring topics exist: {topics}")
    return


