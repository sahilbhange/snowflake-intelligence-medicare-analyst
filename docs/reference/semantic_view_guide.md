# Semantic View Guide

Use this guide when you want to convert the semantic model YAML into a Snowflake semantic view object for deployment and governance.

## Why keep a semantic view in this repo

- [`models/DMEPOS_SEMANTIC_MODEL.yaml`](../../models/DMEPOS_SEMANTIC_MODEL.yaml) stays the authoring source.
- [`models/DMEPOS_SEMANTIC_VIEW.sql`](../../models/DMEPOS_SEMANTIC_VIEW.sql) is the generated, deployable database object DDL.
- Keeping both makes review and deployment clearer: human-friendly modeling in YAML, object-first rollout in SQL.

## How we created it in Snowflake UI

1. Open Snowsight and go to Cortex Analyst semantic modeling.
2. Load or open the semantic model from [`models/DMEPOS_SEMANTIC_MODEL.yaml`](../../models/DMEPOS_SEMANTIC_MODEL.yaml).
3. Use the UI action to generate/create a semantic view from that model.
4. Copy the generated SQL and save it as [`models/DMEPOS_SEMANTIC_VIEW.sql`](../../models/DMEPOS_SEMANTIC_VIEW.sql).
5. Run the SQL in your target schema (example: `MEDICARE_POS_DB.ANALYTICS`).

Note: UI labels can differ slightly across Snowflake versions/accounts, but the workflow is the same: model -> generate semantic view SQL -> execute.

## What the `WITH EXTENSION` block is

In the generated SQL, Snowflake includes a `WITH EXTENSION (CA='...')` section. Treat this as system-generated Cortex Analyst metadata (for example: sample values, filters, verified query payloads, and other model context).

Recommended practice:
- Do not hand-edit this JSON block unless you have a specific reason and retest behavior.
- Regenerate the semantic view SQL from UI after model updates so extension metadata stays consistent.

## Object-first benefits

- Better governance: grants and ownership are managed on a database object.
- Better portability: semantic view DDL can be promoted across environments like other SQL artifacts.
- Better reproducibility: model behavior tied to committed SQL artifact, not only UI state.
- Better operations: aligns with schema migration workflows and review gates.

## Recommended working standard for this repo

1. Edit business semantics in YAML ([`models/DMEPOS_SEMANTIC_MODEL.yaml`](../../models/DMEPOS_SEMANTIC_MODEL.yaml)).
2. Validate with your test prompts.
3. Regenerate [`models/DMEPOS_SEMANTIC_VIEW.sql`](../../models/DMEPOS_SEMANTIC_VIEW.sql) in UI.
4. Commit both files in the same PR when semantics change.

## Related docs

- [Semantic Model Guide](semantic_model_guide.md)
- [Cortex Agent Creation](cortex_agent_creation.md)
- [Semantic Model Lifecycle](../governance/semantic_model_lifecycle.md)
