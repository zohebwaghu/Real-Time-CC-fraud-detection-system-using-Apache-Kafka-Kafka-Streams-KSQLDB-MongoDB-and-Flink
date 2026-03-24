-- ============================================================
-- Q4 — KSQLDB Fraud Detection Queries
-- Run these statements in order inside the KSQLDB CLI:
--   docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
-- ============================================================

-- Process messages from the beginning of each topic
SET 'auto.offset.reset' = 'earliest';

-- ============================================================
-- STEP 1: Source Stream
-- Mirrors the credit_card_transactions Kafka topic.
-- location is a nested JSON object → declared as STRUCT.
-- ============================================================
CREATE STREAM transactions (
    card_number      VARCHAR,
    amount           DOUBLE,
    timestamp        VARCHAR,
    location         STRUCT<city VARCHAR, state VARCHAR>,
    merchant         VARCHAR,
    merchant_category VARCHAR,
    currency         VARCHAR,
    device_type      VARCHAR
) WITH (
    KAFKA_TOPIC  = 'credit_card_transactions',
    VALUE_FORMAT = 'JSON'
);

-- Smoke-test: should return live rows within a few seconds
-- SELECT * FROM transactions EMIT CHANGES LIMIT 5;

-- ============================================================
-- RULE 1 — High Amount (>$500)
-- Simple threshold filter; fires on every oversized charge.
-- ============================================================
CREATE STREAM fraud_high_amount
    WITH (KAFKA_TOPIC = 'flagged_transactions', VALUE_FORMAT = 'JSON') AS
SELECT
    card_number,
    amount,
    location->city        AS city,
    location->state       AS state,
    merchant_category,
    timestamp,
    'HIGH_AMOUNT'         AS fraud_rule,
    'Transaction amount exceeds $500 threshold' AS fraud_reason
FROM transactions
WHERE amount > 500
EMIT CHANGES;

-- ============================================================
-- RULE 2 — Velocity Check (3+ transactions in a 2-minute window)
-- card_number must be the Kafka message key so all transactions
-- for the same card land on the same partition.
-- ============================================================
CREATE TABLE card_velocity AS
SELECT
    card_number,
    COUNT(*)        AS txn_count,
    SUM(amount)     AS total_amount,
    WINDOWSTART     AS window_start,
    WINDOWEND       AS window_end
FROM transactions
    WINDOW TUMBLING (SIZE 2 MINUTES)
GROUP BY card_number
HAVING COUNT(*) >= 3
EMIT CHANGES;

CREATE STREAM fraud_velocity
    WITH (KAFKA_TOPIC = 'flagged_transactions', VALUE_FORMAT = 'JSON') AS
SELECT
    card_number,
    txn_count,
    total_amount,
    'VELOCITY'      AS fraud_rule,
    'Card used ' + CAST(txn_count AS VARCHAR) + ' times in 2-minute window' AS fraud_reason
FROM card_velocity
EMIT CHANGES;

-- ============================================================
-- RULE 3 — Unusual Location (non-US state codes)
-- Flags any transaction whose state is not in the standard
-- US domestic allow-list.
-- ============================================================
CREATE STREAM fraud_unusual_location
    WITH (KAFKA_TOPIC = 'flagged_transactions', VALUE_FORMAT = 'JSON') AS
SELECT
    card_number,
    amount,
    location->city        AS city,
    location->state       AS state,
    merchant_category,
    timestamp,
    'UNUSUAL_LOCATION'    AS fraud_rule,
    'Transaction from unusual location: ' + location->city + ', ' + location->state AS fraud_reason
FROM transactions
WHERE location->state NOT IN (
    'CA', 'NY', 'IL', 'TX', 'FL', 'WA', 'OR', 'NV', 'AZ', 'CO',
    'PA', 'OH', 'GA', 'NC', 'MI', 'NJ', 'VA', 'MA', 'IN', 'MN'
)
EMIT CHANGES;

-- ============================================================
-- RULE 4 — High-Risk Merchant Category
-- Flags transactions at merchant types associated with fraud.
-- ============================================================
CREATE STREAM fraud_high_risk_merchant
    WITH (KAFKA_TOPIC = 'flagged_transactions', VALUE_FORMAT = 'JSON') AS
SELECT
    card_number,
    amount,
    location->city        AS city,
    location->state       AS state,
    merchant_category,
    timestamp,
    'HIGH_RISK_MERCHANT'  AS fraud_rule,
    'Transaction at high-risk merchant category: ' + merchant_category AS fraud_reason
FROM transactions
WHERE merchant_category IN ('gambling', 'crypto_exchange', 'wire_transfer')
EMIT CHANGES;

-- ============================================================
-- RULE 5 — Multi-Factor (high amount AND high-risk merchant)
-- Highest-severity rule: both risk signals present simultaneously.
-- ============================================================
CREATE STREAM fraud_multi_factor
    WITH (KAFKA_TOPIC = 'flagged_transactions', VALUE_FORMAT = 'JSON') AS
SELECT
    card_number,
    amount,
    location->city        AS city,
    location->state       AS state,
    merchant_category,
    timestamp,
    'MULTI_FACTOR'        AS fraud_rule,
    'HIGH SEVERITY: Amount $' + CAST(amount AS VARCHAR) + ' at ' + merchant_category AS fraud_reason
FROM transactions
WHERE amount > 300
  AND merchant_category IN ('gambling', 'crypto_exchange', 'wire_transfer', 'jewelry')
EMIT CHANGES;

-- ============================================================
-- VERIFICATION QUERIES
-- Run these after the producer is running to confirm rules fire.
-- ============================================================

-- Watch all flagged events in real time:
-- PRINT 'flagged_transactions' FROM BEGINNING LIMIT 20;

-- Per-rule spot checks:
-- SELECT * FROM fraud_high_amount        EMIT CHANGES LIMIT 5;
-- SELECT * FROM fraud_unusual_location   EMIT CHANGES LIMIT 5;
-- SELECT * FROM fraud_high_risk_merchant EMIT CHANGES LIMIT 5;
-- SELECT * FROM fraud_multi_factor       EMIT CHANGES LIMIT 5;
-- SELECT * FROM card_velocity            EMIT CHANGES LIMIT 5;

-- Summary counts (run as a push query on the flagged stream):
-- SELECT fraud_rule, COUNT(*) AS hits
--   FROM (
--     SELECT CAST('flagged_transactions' AS VARCHAR) AS topic,
--            fraud_rule
--     FROM flagged_transactions
--   )
-- GROUP BY fraud_rule
-- EMIT CHANGES;
