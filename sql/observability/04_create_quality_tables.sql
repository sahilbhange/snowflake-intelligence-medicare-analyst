-- Lightweight observability quality layer for demo trust metrics.
-- Goal: turn governed agent records into simple daily DQ signals.
-- Prereq: run sql/observability/01_grant_all_privileges.sql once.

USE ROLE MEDICARE_POS_INTELLIGENCE;
USE DATABASE MEDICARE_POS_DB;
USE SCHEMA INTELLIGENCE;

-- Keep a local event table for future custom telemetry use (optional source).
CREATE EVENT TABLE IF NOT EXISTS INTELLIGENCE.AI_OBSERVABILITY_EVENTS;

-- 1) Base quality view from one-row-per-request governed data.
CREATE OR REPLACE VIEW INTELLIGENCE.SEMANTIC_ANALYST_QUALITY AS
SELECT
    g.request_id AS event_id,
    g.trace_id,
    g.agent_name AS app_name,
    TO_VARCHAR(g.agent_version) AS app_version,
    g.user_question,
    g.agent_response,
    g.generated_sql,
    g.total_duration_ms AS latency_ms,
    g.total_tokens AS token_count,
    g.is_successful,
    IFF(TRIM(COALESCE(g.user_question, '')) <> '', TRUE, FALSE) AS has_question,
    IFF(TRIM(COALESCE(g.agent_response, '')) <> '', TRUE, FALSE) AS has_response,
    IFF(TRIM(COALESCE(g.generated_sql, '')) <> '', TRUE, FALSE) AS has_generated_sql,
    g.completion_timestamp AS event_timestamp
FROM GOVERNANCE.AI_AGENT_GOVERNANCE g;

-- 2) Daily DQ summary metrics.
CREATE OR REPLACE VIEW INTELLIGENCE.DAILY_QUALITY_METRICS AS
SELECT
    app_version,
    DATE(event_timestamp) AS metric_date,
    COUNT(*) AS total_queries,
    SUM(IFF(is_successful, 1, 0)) AS success_count,
    ROUND(100.0 * SUM(IFF(is_successful, 1, 0)) / NULLIF(COUNT(*), 0), 1) AS success_rate_pct,
    SUM(IFF(has_response, 1, 0)) AS response_count,
    SUM(IFF(has_generated_sql, 1, 0)) AS sql_count,
    AVG(latency_ms) AS avg_latency_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY latency_ms) AS p95_latency_ms,
    SUM(IFF(is_successful AND has_question AND has_response, 1, 0)) AS dq_pass_count,
    ROUND(
        100.0 * SUM(IFF(is_successful AND has_question AND has_response, 1, 0))
        / NULLIF(COUNT(*), 0),
        1
    ) AS dq_pass_rate_pct
FROM INTELLIGENCE.SEMANTIC_ANALYST_QUALITY
GROUP BY app_version, DATE(event_timestamp)
ORDER BY metric_date DESC;

-- 3) Weekly drift from daily metrics (this week vs prior week).
CREATE OR REPLACE VIEW INTELLIGENCE.WEEKLY_QUALITY_DRIFT AS
WITH this_week AS (
    SELECT
        app_version,
        AVG(success_rate_pct) AS success_rate_pct,
        AVG(dq_pass_rate_pct) AS dq_pass_rate_pct,
        AVG(avg_latency_ms) AS avg_latency_ms
    FROM INTELLIGENCE.DAILY_QUALITY_METRICS
    WHERE metric_date >= DATEADD(day, -7, CURRENT_DATE())
    GROUP BY app_version
),
prior_week AS (
    SELECT
        app_version,
        AVG(success_rate_pct) AS success_rate_pct,
        AVG(dq_pass_rate_pct) AS dq_pass_rate_pct,
        AVG(avg_latency_ms) AS avg_latency_ms
    FROM INTELLIGENCE.DAILY_QUALITY_METRICS
    WHERE metric_date BETWEEN DATEADD(day, -14, CURRENT_DATE()) AND DATEADD(day, -8, CURRENT_DATE())
    GROUP BY app_version
)
SELECT
    w.app_version,
    w.success_rate_pct AS current_success_rate,
    p.success_rate_pct AS prior_success_rate,
    ROUND(w.success_rate_pct - p.success_rate_pct, 2) AS success_rate_delta,
    w.dq_pass_rate_pct AS current_dq_pass_rate,
    p.dq_pass_rate_pct AS prior_dq_pass_rate,
    ROUND(w.dq_pass_rate_pct - p.dq_pass_rate_pct, 2) AS dq_pass_rate_delta,
    w.avg_latency_ms AS current_avg_latency_ms,
    p.avg_latency_ms AS prior_avg_latency_ms,
    ROUND(w.avg_latency_ms - p.avg_latency_ms, 2) AS latency_delta_ms
FROM this_week w
LEFT JOIN prior_week p
    ON w.app_version = p.app_version;

-- 4) Requests that need review.
CREATE OR REPLACE VIEW INTELLIGENCE.LOW_QUALITY_QUESTIONS AS
SELECT
    event_id,
    trace_id,
    app_name,
    app_version,
    event_timestamp,
    user_question,
    generated_sql,
    latency_ms,
    token_count,
    is_successful,
    ARRAY_CONSTRUCT_COMPACT(
        IFF(NOT is_successful, 'execution_failed', NULL),
        IFF(NOT has_question, 'missing_question', NULL),
        IFF(NOT has_response, 'missing_response', NULL),
        IFF(latency_ms > 10000, 'slow_response', NULL)
    ) AS issue_tags
FROM INTELLIGENCE.SEMANTIC_ANALYST_QUALITY
WHERE NOT is_successful
   OR NOT has_question
   OR NOT has_response
   OR latency_ms > 10000
ORDER BY event_timestamp DESC;

-- 5) Alert table used by optional tasks.
CREATE TABLE IF NOT EXISTS INTELLIGENCE.QUALITY_ALERTS (
    alert_id STRING DEFAULT UUID_STRING(),
    alert_type STRING,
    alert_message STRING,
    severity STRING,
    status STRING DEFAULT 'OPEN',
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    acknowledged_at TIMESTAMP_NTZ,
    acknowledged_by STRING,
    resolved_at TIMESTAMP_NTZ,
    notes STRING
);

-- 6) Optional daily alert task (disabled by default for demo).
CREATE OR REPLACE TASK INTELLIGENCE.DAILY_QUALITY_CHECK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 6 * * * America/Los_Angeles'
AS
INSERT INTO INTELLIGENCE.QUALITY_ALERTS (alert_type, alert_message, severity, created_at)
SELECT
    'DAILY_QUALITY' AS alert_type,
    'DQ pass=' || dq_pass_rate_pct || '%, success=' || success_rate_pct || '% for version ' || app_version,
    CASE
        WHEN dq_pass_rate_pct < 80 OR success_rate_pct < 80 THEN 'CRITICAL'
        WHEN dq_pass_rate_pct < 90 OR success_rate_pct < 90 THEN 'WARNING'
        ELSE 'INFO'
    END AS severity,
    CURRENT_TIMESTAMP() AS created_at
FROM INTELLIGENCE.DAILY_QUALITY_METRICS
WHERE metric_date = CURRENT_DATE()
  AND (dq_pass_rate_pct < 95 OR success_rate_pct < 95);

-- Disabled for demo. Enable if you want automatic alert rows.
-- ALTER TASK INTELLIGENCE.DAILY_QUALITY_CHECK RESUME;

-- 7) Quick verification checks.
SELECT 'semantic_quality_view_exists' AS check_name,
       COUNT(*) > 0 AS passed
FROM INFORMATION_SCHEMA.VIEWS
WHERE table_schema = 'INTELLIGENCE'
  AND table_name = 'SEMANTIC_ANALYST_QUALITY'

UNION ALL

SELECT 'daily_metrics_view_exists',
       COUNT(*) > 0
FROM INFORMATION_SCHEMA.VIEWS
WHERE table_schema = 'INTELLIGENCE'
  AND table_name = 'DAILY_QUALITY_METRICS'

UNION ALL

SELECT 'quality_alerts_table_exists',
       COUNT(*) > 0
FROM INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'INTELLIGENCE'
  AND table_name = 'QUALITY_ALERTS';

-- 8) Sample queries.
SELECT *
FROM INTELLIGENCE.DAILY_QUALITY_METRICS
WHERE metric_date >= DATEADD(day, -7, CURRENT_DATE())
ORDER BY metric_date DESC;

SELECT *
FROM INTELLIGENCE.LOW_QUALITY_QUESTIONS
LIMIT 20;

SELECT *
FROM INTELLIGENCE.QUALITY_ALERTS
WHERE status = 'OPEN'
ORDER BY severity DESC, created_at DESC;
