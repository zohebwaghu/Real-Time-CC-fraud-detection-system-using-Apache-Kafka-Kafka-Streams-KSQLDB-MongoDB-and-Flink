# Q7 — Reflection: Real-Time Credit Card Fraud Detection

## Overview

This project built a real-time streaming pipeline that generates synthetic
credit card transactions, routes them through Kafka, applies rule-based fraud
detection in KSQLDB, performs windowed analytics in Flink, and persists
flagged events in MongoDB. Working through each layer gave me a concrete
understanding of how the components of a modern event-driven architecture
each contribute a distinct capability.

---

## Learning Experience

The most valuable takeaway was seeing how each tool maps cleanly to a
specific concern:

- **Kafka** — durable, partitioned message bus; decouples producers from
  every downstream consumer so each can scale and fail independently.
- **KSQLDB** — continuous SQL over streams; excels at low-latency,
  rule-based filtering ("flag this transaction if…") without writing any
  application code.
- **Flink** — stateful stream processor with first-class windowing,
  watermarks, and exactly-once semantics; best for aggregations that span
  time windows and require precise handling of late data.
- **MongoDB** — document store; accepts the heterogeneous JSON shapes
  produced by different KSQLDB fraud rules and makes them queryable
  with flexible ad-hoc aggregation pipelines.

Wiring all four together forced me to think carefully about data formats,
network topology, and consumer group semantics in a way that reading
documentation alone never would.

---

## Challenges Faced

**1. Docker networking**

The biggest operational challenge was inter-container connectivity. Python
scripts running on the host use `localhost:9092` (the external listener),
while KSQLDB and Flink containers must use `kafka:29092` (the internal
`PLAINTEXT` listener on the Docker bridge network). Mixing these up caused
silent connection failures that were hard to diagnose at first.

**2. KSQLDB nested JSON (STRUCT syntax)**

The `location` field is a nested JSON object. KSQLDB requires declaring it
as `STRUCT<city VARCHAR, state VARCHAR>` in the `CREATE STREAM` DDL and
accessing its fields with `->` arrow notation (`location->city`), not dot
notation. The error messages when the wrong syntax is used are not always
obvious.

**3. Kafka message keys and partition co-locality**

The KSQLDB velocity rule counts how many times the same card appears within
a two-minute tumbling window. For that count to be accurate, all messages
for a given card must land on the same partition. Setting
`key=card_number` in the producer ensures Kafka's default hash-partitioner
routes all transactions for a card to one partition, and therefore one
KSQLDB task — without this the window aggregation under-counts.

**4. Fixed card pool for velocity testing**

With fully random card numbers, no card would ever repeat and the velocity
rule would never fire. Seeding a fixed `CARD_POOL` of 50 numbers means each
card appears roughly every 50 messages on average, making the velocity
threshold observable within a typical demo window.

**5. Flink watermark and timestamp format**

Flink's event-time processing requires a `WATERMARK` declaration so the
engine knows how far behind real time each window may be. Using
`TO_TIMESTAMP()` to parse the ISO-8601 string field and setting the
watermark to `transaction_time - INTERVAL '10' SECOND` gave a reasonable
tolerance for the simulated inter-arrival jitter without making windows wait
too long.

**6. MongoDB BSON dates**

MongoDB stores dates as native BSON `Date` objects. The ISO-8601 strings
arriving from Kafka are plain strings unless explicitly converted. The writer
adds an `ingested_at` field as a `datetime` object so time-range queries on
MongoDB work correctly without a string-to-date cast on every query.

---

## Best Practices Discovered

- **Use message keys strategically.** Partition co-locality is not just a
  performance concern — it determines correctness for windowed aggregations.
- **Separate the alert layer from the analytics layer.** KSQLDB handles
  immediate, low-latency alerts (sub-second). Flink handles richer
  analytics where accuracy across time windows matters more than absolute
  latency.
- **Test components independently before connecting the pipeline.** A
  quick `kafka-console-consumer` check confirms messages are flowing before
  debugging KSQLDB streams. A `mongosh` count confirms the writer is active
  before analyzing fraud distribution.
- **Set `auto.offset.reset = earliest` in KSQLDB.** Without this, any
  stream created after the producer started misses historical messages and
  appears empty during a demo.
- **Monitor consumer lag.** Kafka's consumer-group lag metric (visible via
  `kafka-consumer-groups --describe`) shows immediately whether a downstream
  processor is keeping up or falling behind.

---

## Technical Insight: KSQLDB vs. Flink

Despite both consuming Kafka topics and writing SQL-like queries, KSQLDB
and Flink operate at different levels of abstraction and serve different
use cases in this pipeline:

| Dimension | KSQLDB | Flink |
|---|---|---|
| Primary model | Continuous filter / projection | Stateful windowed aggregation |
| Setup complexity | Zero extra infrastructure | Requires its own cluster |
| Latency | Sub-second alert delivery | Slightly higher (watermark delay) |
| Fault tolerance | Good | Excellent (exactly-once via checkpoints) |
| Best for | Rule-based flagging, fan-out to topics | Multi-dimensional analytics, pattern detection |

In a production fraud platform, KSQLDB would power the real-time alert
microservice that calls a card-blocking API within milliseconds of a
suspicious transaction, while Flink would power the analytics dashboard and
the offline model-retraining pipeline that learns from aggregated window
statistics.

---

## Conclusion

Building this end-to-end pipeline made the abstract concept of "stream
processing" concrete. Each message flowing through the system represents a
real decision point — and the latency, ordering guarantees, and windowing
semantics of each layer directly determine whether the fraud detection is
accurate and timely. The hands-on debugging required to get Docker
networking, Kafka partition routing, and Flink watermarks working correctly
provided a depth of understanding that a purely conceptual treatment of
these tools would not.
