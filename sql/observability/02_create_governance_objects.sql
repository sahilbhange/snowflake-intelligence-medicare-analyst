-- Build governance table/view/procedure from SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS.
-- This script is operational; details are documented in docs/trust_layer/trust_layer_architecture.md.

USE ROLE MEDICARE_POS_INTELLIGENCE;
USE DATABASE MEDICARE_POS_DB;
USE SCHEMA GOVERNANCE;

-- 1. GOVERNANCE TABLE

CREATE TABLE IF NOT EXISTS GOVERNANCE.AI_AGENT_GOVERNANCE (
    request_id STRING PRIMARY KEY,
    trace_id STRING,
    user_name STRING,
    role_name STRING,
    thread_id NUMBER,

    query_date DATE,
    query_hour NUMBER,

    agent_name STRING,
    agent_version NUMBER,
    database_name STRING,
    schema_name STRING,
    planning_model STRING,

    user_question STRING,
    agent_response STRING,
    agent_response_raw VARIANT,
    question_category STRING,

    generated_sql STRING,
    tools_used ARRAY,
    tool_types ARRAY,
    used_verified_query BOOLEAN,

    total_duration_ms NUMBER,
    planning_duration_ms NUMBER,
    sql_generation_latency_ms NUMBER,
    performance_category STRING,

    input_tokens NUMBER,
    output_tokens NUMBER,
    total_tokens NUMBER,
    cache_read_tokens NUMBER,
    cache_write_tokens NUMBER,
    cache_hit_rate_pct FLOAT,

    estimated_cost_usd FLOAT,

    execution_status STRING,
    status_code STRING,
    is_successful BOOLEAN,

    start_timestamp TIMESTAMP,
    completion_timestamp TIMESTAMP,
    created_at TIMESTAMP
);

-- 2. GOVERNANCE VIEW

CREATE OR REPLACE VIEW GOVERNANCE.V_AI_GOVERNANCE_PARAMS AS
WITH

-- CTE 1: ROOT SPAN - User interaction data
root_span AS (
    SELECT
        TRACE:trace_id::STRING AS trace_id,

        TIMESTAMP AS completion_timestamp,
        START_TIMESTAMP,

        RESOURCE_ATTRIBUTES:"snow.user.name"::STRING AS user_name,
        RESOURCE_ATTRIBUTES:"snow.session.role.primary.name"::STRING AS role_name,

        RECORD_ATTRIBUTES:"ai.observability.record_id"::STRING AS request_id,

        RECORD_ATTRIBUTES:"ai.observability.record_root.input"::STRING AS user_question,
        RECORD_ATTRIBUTES:"ai.observability.record_root.output"::STRING AS agent_response,

        RECORD_ATTRIBUTES:"snow.ai.observability.agent.thread_id"::NUMBER AS thread_id,
        RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::STRING AS agent_name,
        RECORD_ATTRIBUTES:"snow.ai.observability.object.version.id"::NUMBER AS agent_version,
        RECORD_ATTRIBUTES:"snow.ai.observability.database.name"::STRING AS database_name,
        RECORD_ATTRIBUTES:"snow.ai.observability.schema.name"::STRING AS schema_name,

        RECORD_ATTRIBUTES:"snow.ai.observability.agent.duration"::NUMBER AS total_duration_ms,

        RECORD_ATTRIBUTES:"snow.ai.observability.agent.status"::STRING AS execution_status,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.status.code"::STRING AS status_code

    FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    WHERE RECORD_TYPE = 'SPAN'
      AND RECORD_ATTRIBUTES:"ai.observability.span_type"::STRING = 'record_root'
),

-- CTE 2: PLANNING SPAN - LLM usage and SQL generation
planning_span AS (
    SELECT
        TRACE:trace_id::STRING AS trace_id,

        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.model"::STRING AS planning_model,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.duration"::NUMBER AS planning_duration_ms,

        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.response"::STRING AS planning_response,

        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.messages"::STRING AS planning_messages,

        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.token_count.input"::NUMBER AS input_tokens,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.token_count.output"::NUMBER AS output_tokens,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.token_count.total"::NUMBER AS total_tokens,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.token_count.cache_read_input"::NUMBER AS cache_read_tokens,


        TRY_PARSE_JSON(
            TRY_PARSE_JSON(
                RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.tool_execution.results"::STRING
            )[0]::STRING
        ):sql::STRING AS generated_sql,

        TRY_PARSE_JSON(
            TRY_PARSE_JSON(
                RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.tool_execution.results"::STRING
            )[0]::STRING
        ):verified_query_used::BOOLEAN AS used_verified_query,

        TRY_PARSE_JSON(
            TRY_PARSE_JSON(
                RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.tool_execution.results"::STRING
            )[0]::STRING
        ):analyst_latency_ms::NUMBER AS sql_generation_latency_ms

    FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    WHERE RECORD_TYPE = 'SPAN'
      AND RECORD:name::STRING LIKE '%ResponseGeneration%'
),

-- CTE 3: TOOL SPAN - Tool execution tracking
tool_span AS (
    SELECT
        TRACE:trace_id::STRING AS trace_id,

        ARRAY_AGG(RECORD:name::STRING) AS tools_used,

        ARRAY_AGG(
            CASE
                WHEN RECORD:name::STRING LIKE '%CortexAnalyst%' THEN 'CortexAnalyst'
                WHEN RECORD:name::STRING LIKE '%Chart%' THEN 'ChartGeneration'
                ELSE SPLIT_PART(RECORD:name::STRING, '_', 1)
            END
        ) AS tool_types

    FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    WHERE RECORD_TYPE = 'SPAN'
      AND RECORD:name::STRING LIKE '%Tool%'
    GROUP BY TRACE:trace_id::STRING
),

-- CTE 4: CONVERSATION MESSAGES - Extract all agent responses
conversation_messages AS (
    SELECT
        p.trace_id,
        LISTAGG(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    msg.value::STRING,
                    '^Assistant: ',
                    ''
                ),
                '</?answer>',
                '',
                1, 0, 'e'
            ),
            '\n\n=== NEXT RESPONSE ===\n\n'
        ) WITHIN GROUP (ORDER BY msg.index) AS all_responses
    FROM planning_span p,
    LATERAL FLATTEN(input => TRY_PARSE_JSON(p.planning_messages)) msg
    WHERE msg.value::STRING LIKE 'Assistant:%<answer>%'
    GROUP BY p.trace_id
)

-- MAIN SELECT: Combine all CTEs into one row per trace_id
SELECT
    r.request_id,
    r.trace_id,
    r.user_name,
    r.role_name,
    r.thread_id,

    DATE(r.completion_timestamp) AS query_date,
    HOUR(r.completion_timestamp) AS query_hour,

    r.agent_name,
    r.agent_version,
    r.database_name,
    r.schema_name,
    p.planning_model,

    r.user_question,

    COALESCE(
        c.all_responses,
        p.planning_response,
        r.agent_response
    ) AS agent_response,

    TRY_PARSE_JSON(p.planning_messages) AS agent_response_raw,

    CASE
        WHEN LOWER(r.user_question) LIKE '%top%'
          OR LOWER(r.user_question) LIKE '%highest%'
          THEN 'ranking'
        WHEN LOWER(r.user_question) LIKE '%average%'
          OR LOWER(r.user_question) LIKE '%avg%'
          THEN 'aggregation'
        WHEN LOWER(r.user_question) LIKE '%what is%'
          OR LOWER(r.user_question) LIKE '%define%'
          THEN 'lookup'
        WHEN LOWER(r.user_question) LIKE '%compare%'
          THEN 'comparison'
        ELSE 'other'
    END AS question_category,

    p.generated_sql,

    COALESCE(t.tools_used, ARRAY_CONSTRUCT()) AS tools_used,
    COALESCE(t.tool_types, ARRAY_CONSTRUCT()) AS tool_types,

    p.used_verified_query,

    r.total_duration_ms,
    p.planning_duration_ms,
    p.sql_generation_latency_ms,

    CASE
        WHEN r.total_duration_ms > 10000 THEN 'needs_optimization'
        WHEN r.total_duration_ms > 5000 THEN 'slow'
        WHEN r.total_duration_ms > 2000 THEN 'moderate'
        ELSE 'fast'
    END AS performance_category,

    p.input_tokens,
    p.output_tokens,
    p.total_tokens,
    p.cache_read_tokens,
    0 AS cache_write_tokens,

    ROUND(p.cache_read_tokens * 100.0 / NULLIF(p.input_tokens, 0), 1) AS cache_hit_rate_pct,

    ROUND((p.total_tokens / 1000000.0) * 0.75, 4) AS estimated_cost_usd,

    r.execution_status,
    r.status_code,

    CASE
        WHEN r.execution_status = 'SUCCESS' AND r.status_code = '200' THEN TRUE
        ELSE FALSE
    END AS is_successful,

    r.START_TIMESTAMP AS start_timestamp,
    r.completion_timestamp,

    CURRENT_TIMESTAMP() AS created_at

FROM root_span r
LEFT JOIN planning_span p ON r.trace_id = p.trace_id
LEFT JOIN tool_span t ON r.trace_id = t.trace_id
LEFT JOIN conversation_messages c ON r.trace_id = c.trace_id;


-- 3. STORED PROCEDURE: Populate Governance Table

CREATE OR REPLACE PROCEDURE GOVERNANCE.POPULATE_AI_GOVERNANCE(
    LOOKBACK_DAYS NUMBER DEFAULT 7
)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- Upsert records by request_id 
    MERGE INTO GOVERNANCE.AI_AGENT_GOVERNANCE tgt
    USING (
        SELECT
            request_id,
            trace_id,
            user_name,
            role_name,
            thread_id,
            query_date,
            query_hour,
            agent_name,
            agent_version,
            database_name,
            schema_name,
            planning_model,
            user_question,
            agent_response,
            agent_response_raw,
            question_category,
            generated_sql,
            tools_used,
            tool_types,
            used_verified_query,
            total_duration_ms,
            planning_duration_ms,
            sql_generation_latency_ms,
            performance_category,
            input_tokens,
            output_tokens,
            total_tokens,
            cache_read_tokens,
            cache_write_tokens,
            cache_hit_rate_pct,
            estimated_cost_usd,
            execution_status,
            status_code,
            is_successful,
            start_timestamp,
            completion_timestamp
        FROM GOVERNANCE.V_AI_GOVERNANCE_PARAMS
        WHERE query_date >= DATEADD(day, -:LOOKBACK_DAYS, CURRENT_DATE())
          AND request_id IS NOT NULL
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY request_id
            ORDER BY completion_timestamp DESC NULLS LAST, start_timestamp DESC NULLS LAST
        ) = 1
    ) src
    ON tgt.request_id = src.request_id
    WHEN MATCHED THEN UPDATE SET
        tgt.trace_id = src.trace_id,
        tgt.user_name = src.user_name,
        tgt.role_name = src.role_name,
        tgt.thread_id = src.thread_id,
        tgt.query_date = src.query_date,
        tgt.query_hour = src.query_hour,
        tgt.agent_name = src.agent_name,
        tgt.agent_version = src.agent_version,
        tgt.database_name = src.database_name,
        tgt.schema_name = src.schema_name,
        tgt.planning_model = src.planning_model,
        tgt.user_question = src.user_question,
        tgt.agent_response = src.agent_response,
        tgt.agent_response_raw = src.agent_response_raw,
        tgt.question_category = src.question_category,
        tgt.generated_sql = src.generated_sql,
        tgt.tools_used = src.tools_used,
        tgt.tool_types = src.tool_types,
        tgt.used_verified_query = src.used_verified_query,
        tgt.total_duration_ms = src.total_duration_ms,
        tgt.planning_duration_ms = src.planning_duration_ms,
        tgt.sql_generation_latency_ms = src.sql_generation_latency_ms,
        tgt.performance_category = src.performance_category,
        tgt.input_tokens = src.input_tokens,
        tgt.output_tokens = src.output_tokens,
        tgt.total_tokens = src.total_tokens,
        tgt.cache_read_tokens = src.cache_read_tokens,
        tgt.cache_write_tokens = src.cache_write_tokens,
        tgt.cache_hit_rate_pct = src.cache_hit_rate_pct,
        tgt.estimated_cost_usd = src.estimated_cost_usd,
        tgt.execution_status = src.execution_status,
        tgt.status_code = src.status_code,
        tgt.is_successful = src.is_successful,
        tgt.start_timestamp = src.start_timestamp,
        tgt.completion_timestamp = src.completion_timestamp
    WHEN NOT MATCHED THEN INSERT (
        request_id,
        trace_id,
        user_name,
        role_name,
        thread_id,
        query_date,
        query_hour,
        agent_name,
        agent_version,
        database_name,
        schema_name,
        planning_model,
        user_question,
        agent_response,
        agent_response_raw,
        question_category,
        generated_sql,
        tools_used,
        tool_types,
        used_verified_query,
        total_duration_ms,
        planning_duration_ms,
        sql_generation_latency_ms,
        performance_category,
        input_tokens,
        output_tokens,
        total_tokens,
        cache_read_tokens,
        cache_write_tokens,
        cache_hit_rate_pct,
        estimated_cost_usd,
        execution_status,
        status_code,
        is_successful,
        start_timestamp,
        completion_timestamp,
        created_at
    ) VALUES (
        src.request_id,
        src.trace_id,
        src.user_name,
        src.role_name,
        src.thread_id,
        src.query_date,
        src.query_hour,
        src.agent_name,
        src.agent_version,
        src.database_name,
        src.schema_name,
        src.planning_model,
        src.user_question,
        src.agent_response,
        src.agent_response_raw,
        src.question_category,
        src.generated_sql,
        src.tools_used,
        src.tool_types,
        src.used_verified_query,
        src.total_duration_ms,
        src.planning_duration_ms,
        src.sql_generation_latency_ms,
        src.performance_category,
        src.input_tokens,
        src.output_tokens,
        src.total_tokens,
        src.cache_read_tokens,
        src.cache_write_tokens,
        src.cache_hit_rate_pct,
        src.estimated_cost_usd,
        src.execution_status,
        src.status_code,
        src.is_successful,
        src.start_timestamp,
        src.completion_timestamp,
        CURRENT_TIMESTAMP()
    );

    RETURN 'Successfully merged ' || SQLROWCOUNT || ' records (inserted/updated)';
END;
$$;



call GOVERNANCE.POPULATE_AI_GOVERNANCE();