-- ============================================================
-- Q6 — Flink SQL Real-Time Analytics
--
-- Setup (run once):
--   git clone https://github.com/confluentinc/learn-apache-flink-101-exercises.git
--   cd learn-apache-flink-101-exercises
--   docker compose up --build -d
--   docker compose run sql-client
--
-- If Flink runs inside Docker on the same host as your Kafka
-- container, replace 'localhost:9092' with 'kafka:29092'.
-- ============================================================

-- ============================================================
-- SOURCE TABLE
-- Reads the raw transaction stream from Kafka.
-- transaction_time is derived from the ISO-8601 timestamp field
-- and backed by a 10-second watermark to handle late arrivals.
-- ============================================================
CREATE TABLE transactions (
    card_number       STRING,
    amount            DECIMAL(10, 2),
    `timestamp`       STRING,
    location          ROW<city STRING, state STRING>,
    merchant          STRING,
    merchant_category STRING,
    currency          STRING,
    device_type       STRING,
    -- ISO-8601 "2026-03-21T07:23:33.427679Z" → replace T, keep first 23 chars
    transaction_time  AS TO_TIMESTAMP(SUBSTR(REPLACE(`timestamp`, 'T', ' '), 1, 23)),
    WATERMARK FOR transaction_time AS transaction_time - INTERVAL '10' SECOND
) WITH (
    'connector'                     = 'kafka',
    'topic'                         = 'credit_card_transactions',
    'properties.bootstrap.servers'  = 'localhost:9092',
    'scan.startup.mode'             = 'earliest-offset',
    'format'                        = 'json'
);

-- ============================================================
-- QUERY 1 — Windowed Transaction Statistics (10-second tumble)
-- Provides a rolling pulse of volume and spend every 10 seconds.
-- ============================================================
SELECT
    window_start,
    window_end,
    COUNT(*)                              AS transaction_count,
    CAST(SUM(amount)  AS DECIMAL(10, 2))  AS total_amount,
    CAST(AVG(amount)  AS DECIMAL(10, 2))  AS avg_amount,
    CAST(MIN(amount)  AS DECIMAL(10, 2))  AS min_amount,
    CAST(MAX(amount)  AS DECIMAL(10, 2))  AS max_amount
FROM TABLE(
    TUMBLE(TABLE transactions, DESCRIPTOR(transaction_time), INTERVAL '10' SECOND)
)
GROUP BY window_start, window_end;

-- ============================================================
-- QUERY 2 — Location Hotspots (30-second tumble)
-- Which cities generate the most transaction volume?
-- Useful for spotting sudden geographic spikes.
-- ============================================================
SELECT
    location.city                         AS city,
    location.state                        AS state,
    COUNT(*)                              AS txn_count,
    CAST(SUM(amount)  AS DECIMAL(10, 2))  AS total_amount,
    CAST(AVG(amount)  AS DECIMAL(10, 2))  AS avg_amount
FROM TABLE(
    TUMBLE(TABLE transactions, DESCRIPTOR(transaction_time), INTERVAL '30' SECOND)
)
GROUP BY location.city, location.state;

-- ============================================================
-- QUERY 3 — Merchant Category Breakdown (30-second tumble)
-- Detects unusual spikes in high-risk categories in real time.
-- ============================================================
SELECT
    merchant_category,
    COUNT(*)                              AS txn_count,
    CAST(SUM(amount)  AS DECIMAL(10, 2))  AS total_spend,
    CAST(AVG(amount)  AS DECIMAL(10, 2))  AS avg_spend
FROM TABLE(
    TUMBLE(TABLE transactions, DESCRIPTOR(transaction_time), INTERVAL '30' SECOND)
)
GROUP BY merchant_category
ORDER BY total_spend DESC;

-- ============================================================
-- QUERY 4 — Fraud Ring Detection (60-second tumble)
-- Flags merchants where 3+ distinct cards transact in 1 minute,
-- a pattern consistent with coordinated fraud rings.
-- ============================================================
SELECT
    merchant,
    COUNT(DISTINCT card_number)           AS unique_cards,
    COUNT(*)                              AS total_txns,
    CAST(SUM(amount)  AS DECIMAL(10, 2))  AS total_amount
FROM TABLE(
    TUMBLE(TABLE transactions, DESCRIPTOR(transaction_time), INTERVAL '60' SECOND)
)
GROUP BY merchant
HAVING COUNT(DISTINCT card_number) >= 3;

-- ============================================================
-- QUERY 5 — High-Velocity Card Detection (60-second tumble)
-- Identifies individual cards with 3+ transactions per minute.
-- Complements the KSQLDB velocity rule with richer aggregates.
-- ============================================================
SELECT
    card_number,
    COUNT(*)                              AS txn_count,
    CAST(SUM(amount)  AS DECIMAL(10, 2))  AS total_spend,
    CAST(MAX(amount)  AS DECIMAL(10, 2))  AS max_single_txn
FROM TABLE(
    TUMBLE(TABLE transactions, DESCRIPTOR(transaction_time), INTERVAL '60' SECOND)
)
GROUP BY card_number
HAVING COUNT(*) >= 3;
