"""
Q3 — Kafka Producer
Sends generated transactions to the credit_card_transactions topic.
Uses card_number as the message key so the same card always lands on
the same partition — required for KSQLDB's windowed velocity check.
"""

import json
import time
import random

from kafka import KafkaProducer
from generator import generate_transaction

TOPIC = "credit_card_transactions"
BOOTSTRAP = "localhost:9092"


def create_producer() -> KafkaProducer:
    return KafkaProducer(
        bootstrap_servers=BOOTSTRAP,
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        key_serializer=lambda k: k.encode("utf-8") if k else None,
    )


def main() -> None:
    producer = create_producer()
    print(f"Producing to topic: {TOPIC}  (Ctrl-C to stop)")
    count = 0

    try:
        while True:
            txn = generate_transaction(fraud_probability=0.15)

            producer.send(
                TOPIC,
                key=txn["card_number"],
                value=txn,
            )
            producer.flush()

            count += 1
            if count % 10 == 0:
                print(
                    f"  [{count:>5}] ${txn['amount']:>8.2f}  "
                    f"{txn['location']['city']}, {txn['location']['state']:<3}  "
                    f"[{txn['merchant_category']}]"
                )

            # ~1 transaction per second with some jitter
            time.sleep(random.uniform(0.2, 1.5))

    except KeyboardInterrupt:
        print(f"\nStopped. Total sent: {count}")
    finally:
        producer.close()


if __name__ == "__main__":
    main()
