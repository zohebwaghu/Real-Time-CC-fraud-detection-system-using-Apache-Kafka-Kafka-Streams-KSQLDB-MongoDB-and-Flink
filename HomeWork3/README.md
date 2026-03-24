# DATA 228 — Homework 3: Real-Time Credit Card Fraud Detection

**Stack:** Kafka · KSQLDB · MongoDB · Flink  
**Points:** 40 total

---

## Quick-Start

```bash
# 1. Install Python dependencies
pip install -r requirements.txt

# 2. Start infrastructure (Kafka, KSQLDB, MongoDB)
docker-compose up -d

# 3. Wait ~30 seconds, then create the Kafka topics
docker exec kafka kafka-topics --create \
  --topic credit_card_transactions \
  --bootstrap-server localhost:9092 \
  --partitions 3 --replication-factor 1

docker exec kafka kafka-topics --create \
  --topic flagged_transactions \
  --bootstrap-server localhost:9092 \
  --partitions 3 --replication-factor 1

# 4. Run the producer (Terminal A)
python producer.py

# 5. Load KSQLDB fraud rules (Terminal B)
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
# Paste contents of ksqldb_queries.sql one block at a time

# 6. Start the MongoDB writer (Terminal C)
python mongodb_writer.py

# 7. Run Flink analytics — option A: Flink SQL client
git clone https://github.com/confluentinc/learn-apache-flink-101-exercises.git
cd learn-apache-flink-101-exercises && docker compose up --build -d
docker compose run sql-client
# Paste contents of flink_queries.sql

# 7. Run Flink analytics — option B: PyFlink
python flink_analytics.py

# 8. Verify MongoDB
docker exec -it mongodb mongosh
# use fraud_detection
# db.flagged_transactions.countDocuments()
# db.flagged_transactions.aggregate([{$group:{_id:"$fraud_rule",count:{$sum:1}}}])
```

---

## File Map

| File | Question | Points |
|---|---|---|
| `docker-compose.yml` | Q1 — Environment setup | 5 |
| `generator.py` | Q2 — Faker data generator | 2 |
| `producer.py` | Q3 — Kafka producer | 3 |
| `ksqldb_queries.sql` | Q4 — KSQLDB fraud detection | 10 |
| `mongodb_writer.py` | Q5 — MongoDB writer | 5 |
| `flink_queries.sql` | Q6 — Flink SQL analytics | 10 |
| `flink_analytics.py` | Q6 — PyFlink alternative | — |
| `reflection.md` | Q7 — Reflection write-up | 5 |

---

## Architecture

```
generator.py ──► Kafka (credit_card_transactions)
                        │
                        ├──► KSQLDB (5 fraud rules) ──► Kafka (flagged_transactions)
                        │                                          │
                        │                                          └──► mongodb_writer.py ──► MongoDB
                        │
                        └──► Flink SQL / PyFlink (5 analytics queries)
```

---

## KSQLDB Fraud Rules

| Rule | Trigger | Severity |
|---|---|---|
| `HIGH_AMOUNT` | amount > $500 | Medium |
| `VELOCITY` | 3+ txns from same card in 2 min | High |
| `UNUSUAL_LOCATION` | Non-US state code | Medium |
| `HIGH_RISK_MERCHANT` | gambling / crypto / wire transfer | High |
| `MULTI_FACTOR` | amount > $300 AND high-risk merchant | Critical |

---

## Flink Analytics Queries

1. **Windowed stats** — count, sum, avg, min, max per 10-second tumble  
2. **Location hotspots** — city/state transaction volume per 30-second tumble  
3. **Merchant category breakdown** — spend by category per 30-second tumble  
4. **Fraud ring detection** — merchants with ≥3 distinct cards in 60 seconds  
5. **High-velocity cards** — cards with ≥3 transactions in 60 seconds  
