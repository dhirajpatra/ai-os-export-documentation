import os
import json
import socket
from aiokafka import AIOKafkaProducer

_producer = None

def get_kafka_bootstrap() -> str:
    """
    Resolves Kafka bootstrap servers.
    Checks KAFKA_BOOTSTRAP_SERVERS, falling back to KAFKA_BOOTSTRAP or 'kafka:9092'.
    If the hostname is 'kafka' but DNS resolution fails, automatically falls back
    to '127.0.0.1:9092' (useful when running the API locally outside Docker).
    """
    bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS") or os.getenv("KAFKA_BOOTSTRAP") or "kafka:9092"
    host = "kafka"
    port = 9092
    if ":" in bootstrap_servers:
        parts = bootstrap_servers.rsplit(":", 1)
        if len(parts) == 2:
            host, p_str = parts
            try:
                port = int(p_str)
            except ValueError:
                pass

    try:
        socket.gethostbyname(host)
    except socket.gaierror:
        if host == "kafka":
            print(f"[KafkaProducer] 'kafka' DNS resolution failed. Falling back to 127.0.0.1:{port}")
            return f"127.0.0.1:{port}"
    return bootstrap_servers

async def get_producer():
    global _producer
    if _producer is None:
        bootstrap_servers = get_kafka_bootstrap()
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

async def ensure_kafka_topics(topics: list[str]) -> None:
    """
    Ensures that the specified Kafka topics exist.
    If they do not exist, tries to create them via AIOKafkaAdminClient.
    """
    from aiokafka.admin import AIOKafkaAdminClient, NewTopic
    bootstrap_servers = get_kafka_bootstrap()
    admin = AIOKafkaAdminClient(bootstrap_servers=bootstrap_servers)
    try:
        await admin.start()
        existing_topics = await admin.list_topics()
        new_topics = []
        for t in topics:
            if t not in existing_topics:
                print(f"[KafkaProducer] Topic '{t}' does not exist. Initiating creation...")
                new_topics.append(NewTopic(name=t, num_partitions=1, replication_factor=1))
        if new_topics:
            await admin.create_topics(new_topics=new_topics, validate_only=False)
            print(f"[KafkaProducer] Topics created successfully: {[nt.name for nt in new_topics]}")
    except Exception as e:
        print(f"[KafkaProducer] Failed to ensure topics exist: {e}")
    finally:
        try:
            await admin.close()
        except Exception:
            pass


