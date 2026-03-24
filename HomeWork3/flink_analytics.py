"""
Q6 — PyFlink Alternative
Use this if the Flink SQL client environment is unavailable.
Runs the same windowed analytics via the PyFlink Table API.

Prerequisites (one-time setup, already done):
  pip install apache-flink jdk4py==17.0.9.2

  # Kafka connector JAR must be in PyFlink's lib directory:
  curl -L https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/4.0.1-2.0/flink-sql-connector-kafka-4.0.1-2.0.jar \
       -o $(python -c "import pyflink; import os; print(os.path.join(os.path.dirname(pyflink.__file__), 'lib'))")/flink-sql-connector-kafka-4.0.1-2.0.jar
"""

import os
import jdk4py

# Point PyFlink at the bundled JDK before importing any pyflink modules
os.environ.setdefault("JAVA_HOME", str(jdk4py.JAVA_HOME))

from pyflink.table import EnvironmentSettings, TableEnvironment

BOOTSTRAP = "localhost:9092"


RESULTS_PER_QUERY = 10  # rows to collect before moving to the next query


def run_query(table_env: TableEnvironment, label: str, sql: str) -> None:
    """Execute a streaming SQL query and print up to RESULTS_PER_QUERY rows."""
    print(f"\n{'='*60}")
    print(f" {label}")
    print('='*60)
    result = table_env.execute_sql(sql)
    collected = 0
    with result.collect() as rows:
        for row in rows:
            print(row)
            collected += 1
            if collected >= RESULTS_PER_QUERY:
                break
    if collected == 0:
        print("  (no completed windows yet — try again with more data)")


def main() -> None:
    settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
    table_env = TableEnvironment.create(environment_settings=settings)

    # Source table using processing time — windows close every N real seconds,
    # no watermark lag, works immediately with live data.
    table_env.execute_sql(f"""
        CREATE TABLE transactions (
            card_number       STRING,
            amount            DECIMAL(10, 2),
            `timestamp`       STRING,
            merchant_category STRING,
            location          ROW<city STRING, state STRING>,
            merchant          STRING,
            device_type       STRING,
            proc_time         AS PROCTIME()
        ) WITH (
            'connector'                    = 'kafka',
            'topic'                        = 'credit_card_transactions',
            'properties.bootstrap.servers' = '{BOOTSTRAP}',
            'scan.startup.mode'            = 'latest-offset',
            'format'                       = 'json'
        )
    """)

    run_query(table_env, "Query 1: 10-second windowed statistics", """
        SELECT
            window_start,
            window_end,
            COUNT(*)                             AS txn_count,
            CAST(SUM(amount) AS DECIMAL(10, 2))  AS total_amount,
            CAST(AVG(amount) AS DECIMAL(10, 2))  AS avg_amount,
            CAST(MIN(amount) AS DECIMAL(10, 2))  AS min_amount,
            CAST(MAX(amount) AS DECIMAL(10, 2))  AS max_amount
        FROM TABLE(
            TUMBLE(TABLE transactions, DESCRIPTOR(proc_time), INTERVAL '10' SECOND)
        )
        GROUP BY window_start, window_end
    """)

    run_query(table_env, "Query 2: Location hotspots (30-second window)", """
        SELECT
            location.city                        AS city,
            location.state                       AS state,
            COUNT(*)                             AS txn_count,
            CAST(SUM(amount) AS DECIMAL(10, 2))  AS total_amount
        FROM TABLE(
            TUMBLE(TABLE transactions, DESCRIPTOR(proc_time), INTERVAL '30' SECOND)
        )
        GROUP BY location.city, location.state
    """)

    run_query(table_env, "Query 3: Merchant category breakdown (30-second window)", """
        SELECT
            merchant_category,
            COUNT(*)                             AS txn_count,
            CAST(SUM(amount) AS DECIMAL(10, 2))  AS total_spend,
            CAST(AVG(amount) AS DECIMAL(10, 2))  AS avg_spend
        FROM TABLE(
            TUMBLE(TABLE transactions, DESCRIPTOR(proc_time), INTERVAL '30' SECOND)
        )
        GROUP BY merchant_category
    """)

    run_query(table_env, "Query 4: Fraud ring detection (60-second window, >=3 distinct cards)", """
        SELECT
            merchant,
            COUNT(DISTINCT card_number)          AS unique_cards,
            COUNT(*)                             AS total_txns,
            CAST(SUM(amount) AS DECIMAL(10, 2))  AS total_amount
        FROM TABLE(
            TUMBLE(TABLE transactions, DESCRIPTOR(proc_time), INTERVAL '60' SECOND)
        )
        GROUP BY merchant
        HAVING COUNT(DISTINCT card_number) >= 3
    """)

    run_query(table_env, "Query 5: High-velocity cards (60-second window, >=3 txns)", """
        SELECT
            card_number,
            COUNT(*)                             AS txn_count,
            CAST(SUM(amount) AS DECIMAL(10, 2))  AS total_spend,
            CAST(MAX(amount) AS DECIMAL(10, 2))  AS max_single_txn
        FROM TABLE(
            TUMBLE(TABLE transactions, DESCRIPTOR(proc_time), INTERVAL '60' SECOND)
        )
        GROUP BY card_number
        HAVING COUNT(*) >= 3
    """)

    print("\nAll queries complete.")


if __name__ == "__main__":
    main()
