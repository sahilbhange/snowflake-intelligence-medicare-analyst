# Creating Cortex Agents with SQL

Use this guide when creating the demo Cortex Agent that orchestrates Cortex Analyst and Cortex Search services.

## Overview

A Cortex Agent is an AI orchestrator that can:
- Route user questions to the right tool (Cortex Analyst for metrics, Cortex Search for lookups)
- Combine results from multiple tools into a single answer
- Follow instructions on when to use each tool
- Autonomously handle follow-up logic (retry with synonyms, ask for clarification)

## Agent Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│              User Query                                           │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
            ┌────────────────────────────────┐
            │   Cortex Agent (Orchestrator)  │
            │   - Parse question             │
            │   - Decide which tool to use   │
            │   - Execute and combine        │
            └────────────┬───────────┬───────┘
                         │           │
           ┌─────────────┴──┐   ┌────┴────────────────┐
           │                │   │                     │
           ▼                ▼   ▼                     ▼
    ┌────────────────┐ ┌──────────────────┐ ┌────────────────────┐
    │ Cortex Analyst │ │ Cortex Search    │ │ Cortex Search      │
    │ (Metrics)      │ │ (HCPCS Codes)    │ │ (PDF Policies)     │
    └────────────────┘ └──────────────────┘ └────────────────────┘
```

## Step 1: Prepare Semantic Artifacts (view-first)

The demo uses semantic view as the agent binding artifact.

1. Create or refresh semantic view before agent creation:

```bash
make semantic-view
```

2. Optional: keep YAML staged only for Cortex Analyst UI workflows:
- `PUT file://models/DMEPOS_SEMANTIC_MODEL.yaml @MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG AUTO_COMPRESS=FALSE OVERWRITE=TRUE;`

See [Semantic View Guide](semantic_view_guide.md) for the UI workflow and `WITH EXTENSION` notes.

## Step 2: Create Cortex Search Services (if needed)

The agent uses pre-built Cortex Search services. Ensure these exist:

```sql
-- Verify search services are ready
SHOW CORTEX SEARCH SERVICES IN SEARCH;
```

Expected services:
- `HCPCS_SEARCH_SVC` - HCPCS code definitions
- `DEVICE_SEARCH_SVC` - Medical device catalog
- `PROVIDER_SEARCH_SVC` - Provider directory
- `PDF_SEARCH_SVC` - CMS policy PDFs (optional)

See [Embedding Strategy](embedding_strategy.md) for implementation details, including optional PDF search.

## Step 3: Define Agent Instructions

Create clear instructions for the agent on when to use each tool:

```yaml
instructions:
  orchestration: |
    You are a data assistant for Medicare DMEPOS analytics.

    Tool selection rules:

    1. Use Cortex Search when:
       - User asks for definitions ("what is", "define", "meaning")
       - Looking up codes/providers ("find", "search for")
       - Policy questions ("guidance", "rules")

    2. Use Cortex Analyst when:
       - User asks for metrics ("total", "count", "average")
       - Comparisons ("vs", "compare")
       - Rankings ("top", "highest", "lowest")

    3. For mixed questions (definition + metrics):
       a) Search first to get canonical IDs
       b) Use Analyst with those IDs for metrics
       c) Combine results in one response

  response: |
    Format:
    - If Search: show 2-5 results with snippets
    - If Analyst: show metrics with units in a table
    - If both: "Lookup" section then "Analysis" section
```

## Step 4: Create the Agent with CREATE AGENT

The agent specification follows this structure:

```yaml
models:
  orchestration: auto

orchestration:
  budget:
    seconds: 300  # Max execution time

instructions:
  orchestration: |
    Routing rules for when to use each tool
    
tools:
  - Tool definitions (Analyst + Search services)

tool_resources:
  DMEPOS_ANALYST:
    semantic_view: "DB.SCHEMA.SEMANTIC_VIEW_NAME"  # Repo default for agent setup
  
  Tool_Search:
    name: "DB.SCHEMA.SERVICE_NAME"
    max_results: "5-10"
    id_column: "UNIQUE_ID"
    title_column: "DISPLAY_COLUMN"
```

**Full implementation:** See [sql/agent/cortex_agent.sql](../../sql/agent/cortex_agent.sql)

## Step 5: Grant Permissions

```sql
GRANT USAGE ON AGENT MEDICARE_POS_DB.ANALYTICS.DMEPOS_INTELLIGENCE_AGENT_SQL
  TO ROLE MEDICARE_POS_INTELLIGENCE;
```

## Step 6: Test the Agent

### In Snowsight UI

Navigate to **Agents** → **DMEPOS_INTELLIGENCE_AGENT_SQL** → Enter a question.

### Via SQL

```sql
-- Call agent and get response
CALL MEDICARE_POS_DB.ANALYTICS.DMEPOS_INTELLIGENCE_AGENT_SQL('What are the top 10 HCPCS codes by claims volume?');

-- View agent execution history
SELECT * FROM TABLE(INFORMATION_SCHEMA.AGENTS())
WHERE AGENT_NAME = 'DMEPOS_INTELLIGENCE_AGENT_SQL';
```

## Key Configuration Options

| Parameter | Purpose | Example |
|-----------|---------|---------|
| `orchestration: auto` | Agent decides which tools to use | `auto` (recommended) |
| `budget.seconds` | Max execution time per query | `300` (5 minutes) |
| `max_results` (per tool) | Limit results per tool call | `5-10` |
| `id_column` | Unique identifier for results | `HCPCS_CODE`, `REFERRING_NPI` |
| `title_column` | Display name for results | `HCPCS_CODE`, `BRAND_NAME` |

## Tool Resource Mapping

Each tool must map to:
1. **For Cortex Analyst:** A semantic view object
2. **For Cortex Search:** A Cortex Search service name

For this repo's standard:
- Semantic view powers agent tool binding.
- Semantic view SQL is tracked in [`models/DMEPOS_SEMANTIC_VIEW.sql`](../../models/DMEPOS_SEMANTIC_VIEW.sql).

```yaml
tool_resources:
  DMEPOS_ANALYST:
    semantic_view: "MEDICARE_POS_DB.ANALYTICS.DMEPOS_SEMANTIC_MODEL"  # Analyst

  HCPCS_Code_Search:
    name: "DB.SCHEMA.HCPCS_SEARCH_SVC"  # Search service
    max_results: "8"
    id_column: "HCPCS_CODE"
    title_column: "HCPCS_CODE"
```

## Agent Behavior

### When User Asks: "What is HCPCS E1390?"

1. Agent recognizes definition request
2. Routes to `HCPCS_Code_Search`
3. Returns code definition + related codes
4. Response: "HCPCS E1390 is an oxygen concentrator..."

### When User Asks: "Total claims for E1390 in CA"

1. Agent recognizes metric request
2. Routes to `DMEPOS_ANALYST`
3. Uses semantic view to query claims
4. Response: "2,450 claims totaling $1.2M in CA"

### When User Asks: "What is E1390 and how much do we bill?"

1. Agent recognizes mixed request
2. Step 1: Search for E1390 definition (Cortex Search)
3. Step 2: Use identifier E1390 to get metrics (Cortex Analyst)
4. Response: Combined answer with definition + metrics

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Agent returns "Tool not found" | Verify tool name matches `tool_spec.name` exactly |
| "Semantic model/view not accessible" | Check semantic view name and role permissions |
| Agent times out (>300 sec) | Reduce `budget.seconds` or simplify instructions |
| Search returns no results | Verify search service exists and has data |

## Best Practices

1. **Keep instructions concise** - Avoid overly long rule sets
2. **Test tools independently first** - Verify search services and semantic view work before adding to agent
3. **Use descriptive names** - `HCPCS_Code_Search` > `Search_1`
4. **Set realistic max_results** - 5-10 for search, auto for analyst
5. **Provide fallback guidance** - Tell agent what to do if tools fail
6. **Monitor execution** - Check `INFORMATION_SCHEMA.AGENTS()` for errors

## Related Documentation

- [Embedding Strategy](embedding_strategy.md) - Creating Cortex Search services
- [Agent Guidance](agent_guidance.md) - Routing rules and best practices
- [Semantic Model Lifecycle](../governance/semantic_model_lifecycle.md) - Managing models
- [Snowflake Agents Docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/agents)

## Example: Full Agent Specification

See [sql/agent/cortex_agent.sql](../../sql/agent/cortex_agent.sql) for a complete working agent implementation.
