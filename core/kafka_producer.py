import os
import json
from aiokafka import AIOKafkaProducer

_producer = None

async def get_producer():
    global _producer
    if _producer is None:
        bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
        try:
            _producer = AIOKafkaProducer(
                bootstrap_servers=bootstrap_servers,
                value_serializer=lambda v: json.dumps(v).encode('utf-8')
            )
            await _producer.start()
        except Exception as e:
            print(f"[KafkaProducer] Failed to initialize: {e}")
            _producer = None
    return _producer

async def send_event(topic: str, event_type: str, payload: dict):
    try:
        producer = await get_producer()
        if not producer:
            return
        message = {
            "event_type": event_type,
            "payload": payload
        }
        await producer.send_and_wait(topic, message)
    except Exception as e:
        print(f"[KafkaProducer] Failed to send event to {topic}: {e}")
