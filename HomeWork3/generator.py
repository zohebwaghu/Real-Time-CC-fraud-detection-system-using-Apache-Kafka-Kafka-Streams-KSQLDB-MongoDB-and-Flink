"""
Q2 — Faker Data Generator
Generates synthetic credit card transactions with ~15% injected fraud signals.
"""

import random
from datetime import datetime
from faker import Faker

fake = Faker()

# Fixed pool of 50 card numbers so the velocity rule (Q4) sees repeats
CARD_POOL = [fake.credit_card_number() for _ in range(50)]

MERCHANT_CATEGORIES = [
    "grocery", "restaurant", "gas_station", "online_retail",
    "electronics", "travel", "entertainment", "healthcare",
    "jewelry", "gambling",
    "crypto_exchange", "wire_transfer",
]

HIGH_RISK_MERCHANTS = {"gambling", "crypto_exchange", "wire_transfer", "jewelry"}

# Normal US locations plus three high-suspicion foreign cities
LOCATIONS = [
    ("San Jose", "CA"), ("San Francisco", "CA"), ("Los Angeles", "CA"),
    ("New York", "NY"), ("Chicago", "IL"), ("Houston", "TX"),
    ("Lagos", "NG"), ("Moscow", "RU"), ("Shenzhen", "CN"),
]

US_LOCATIONS = LOCATIONS[:6]
FOREIGN_LOCATIONS = LOCATIONS[6:]


def generate_transaction(fraud_probability: float = 0.15) -> dict:
    """
    Generate one credit card transaction dict.

    Fraud injection types:
      high_amount       — large USD charge at a normal US merchant
      unusual_location  — normal amount but from a foreign city/state
      high_risk_merchant— moderate amount at gambling/crypto/wire/jewelry
      rapid_fire        — small amount, same card used quickly (velocity rule)
    """
    is_fraud = random.random() < fraud_probability

    if is_fraud:
        fraud_type = random.choice(
            ["high_amount", "unusual_location", "high_risk_merchant", "rapid_fire"]
        )

        if fraud_type == "high_amount":
            amount = round(random.uniform(800, 9999), 2)
            city, state = random.choice(US_LOCATIONS)
            merchant_cat = random.choice(MERCHANT_CATEGORIES[:8])

        elif fraud_type == "unusual_location":
            amount = round(random.uniform(50, 500), 2)
            city, state = random.choice(FOREIGN_LOCATIONS)
            merchant_cat = random.choice(MERCHANT_CATEGORIES)

        elif fraud_type == "high_risk_merchant":
            amount = round(random.uniform(100, 2000), 2)
            city, state = random.choice(US_LOCATIONS)
            merchant_cat = random.choice(list(HIGH_RISK_MERCHANTS))

        else:  # rapid_fire — same card used in quick succession
            amount = round(random.uniform(20, 200), 2)
            city, state = random.choice(US_LOCATIONS)
            merchant_cat = random.choice(MERCHANT_CATEGORIES[:8])

    else:
        amount = round(random.uniform(1, 300), 2)
        city, state = random.choice(US_LOCATIONS)
        merchant_cat = random.choice(MERCHANT_CATEGORIES[:8])

    return {
        "card_number": random.choice(CARD_POOL),
        "amount": amount,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "location": {
            "city": city,
            "state": state,
        },
        "merchant": fake.company(),
        "merchant_category": merchant_cat,
        "currency": "USD",
        "device_type": random.choice(["mobile", "desktop", "pos_terminal", "atm"]),
    }


if __name__ == "__main__":
    for i in range(5):
        txn = generate_transaction()
        print(f"[{i + 1}] ${txn['amount']:.2f} | {txn['merchant_category']} | "
              f"{txn['location']['city']}, {txn['location']['state']}")
