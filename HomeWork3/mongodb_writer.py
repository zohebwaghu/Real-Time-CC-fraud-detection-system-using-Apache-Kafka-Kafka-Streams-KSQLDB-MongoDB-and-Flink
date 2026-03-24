"""
Q5 — MongoDB Writer
Consumes the flagged_transactions Kafka topic and persists each
flagged event into MongoDB for durable storage and ad-hoc querying.
"""

import json
from datetime import datetime, UTC

from kafka import KafkaConsumer
from pymongo import MongoClient, ASCENDING

TOPIC = "flagged_transactions"
BOOTSTRAP = "localhost:9092"
MONGO_URI = "mongodb://localhost:27017"
DB_NAME = "fraud_detection"
COLLECTION_NAME = "flagged_transactions"


def main() -> None:
    client = MongoClient(MONGO_URI)
    db = client[DB_NAME]
    collection = db[COLLECTION_NAME]

    # Indexes for common query patterns
    collection.create_index([("card_number", ASCENDING)])
    collection.create_index([("fraud_rule", ASCENDING)])
    collection.create_index([("ingested_at", ASCENDING)])

    consumer = KafkaConsumer(
        TOPIC,
        bootstrap_servers=BOOTSTRAP,
        value_deserializer=lambda m: json.loads(m.decode("utf-8")),
        auto_offset_reset="earliest",
        group_id="mongodb_writer_group",
    )

    print(f"Consuming '{TOPIC}' → MongoDB {DB_NAME}.{COLLECTION_NAME}  (Ctrl-C to stop)")
    count = 0

    try:
        for msg in consumer:
            raw = msg.value

            # KSQLDB emits uppercase field names — normalize everything to lowercase
            doc = {k.lower(): v for k, v in raw.items()}

            # Enrich with Kafka metadata and ingestion timestamp
            doc["ingested_at"] = datetime.now(UTC)
            doc["kafka_partition"] = msg.partition
            doc["kafka_offset"] = msg.offset

            collection.insert_one(doc)
            count += 1

            if count % 5 == 0:
                print(
                    f"  [{count:>5}] stored | rule={doc.get('fraud_rule', 'unknown'):<22} "
                    f"card=...{str(doc.get('card_number', ''))[-4:]}"
                )

    except KeyboardInterrupt:
        print(f"\nStopped. Total stored: {count}")
    finally:
        consumer.close()
        client.close()


if __name__ == "__main__":
    main()
