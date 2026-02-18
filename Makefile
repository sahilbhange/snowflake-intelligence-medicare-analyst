# Demo-first automation for Snowflake Intelligence Medicare Analyst.
# What this Makefile does:
# - Orchestrates Snowflake SQL scripts in deployment order.
# - Supports log capture via `make deploy-all` or `make log TARGET=<target>`.
#
# Most used targets:
# - `make demo`      : data + setup + load + transform + search + governance + observability
# - `make agent`     : semantic view + search services + Cortex Agent
# - `make test`      : semantic regression checks
# - `make help`      : quick command reference
#
# Connection defaults:
# - Uses Snowflake CLI connection `sf_int` (`SNOW_OPTS ?= sql -c sf_int`).
# - Override per run: `make SNOW_OPTS="sql -c <connection_name>" demo`

SNOW ?= snow
SNOW_OPTS ?= sql -c sf_int
SNOW_CMD := $(SNOW) $(SNOW_OPTS)
PYTHON ?= python
LOG_DIR ?= logs
TARGET ?= demo
LOG_FILE ?= $(LOG_DIR)/$(TARGET)_$(shell date +%Y%m%d_%H%M%S).log

.DEFAULT_GOAL := help
.NOTPARALLEL:

.PHONY: help \
	data setup stage-raw load transform semantic-view search \
	pdf-setup pdf-upload search-pdf pdf-validate \
	metadata metadata-demo profile profile-demo governance-demo \
	observability-bootstrap observability \
	instrumentation knowledge-graph validation grants \
	agent test tests verify clean-tests \
	demo deploy deploy-all \
	log \
	teardown reset

define run_sql
	$(SNOW_CMD) -f $(1)
endef

# ------------------------------
# Data + Infra
# ------------------------------

# Download source datasets to local files used by ingestion.
data:
	@echo "Downloading source data"
	$(PYTHON) data/dmepos_referring_provider_download.py --max-rows 1000000
	bash data/data_download.sh

# Create Snowflake role, warehouse, database, schemas, and base grants.
setup:
	@echo "Setting up Snowflake infrastructure"
	$(call run_sql,sql/setup/setup_user_and_roles.sql)

# Upload local raw files to Snowflake internal stages.
stage-raw:
	@echo "Uploading local raw files to Snowflake internal stages"
	@test -f data/dmepos_referring_provider.json || (echo "Missing data/dmepos_referring_provider.json. Run 'make data' first."; exit 1)
	@test -d data/gudid_delimited || (echo "Missing data/gudid_delimited/. Run 'make data' first."; exit 1)
	$(call run_sql,sql/ingestion/stage_raw_files.sql)

# Load staged raw files into RAW schema tables.
load:
	@echo "Loading raw data"
	$(MAKE) stage-raw
	$(call run_sql,sql/ingestion/load_raw_data.sql)

# Build curated and analytics layer objects.
transform:
	@echo "Building curated + analytics model"
	$(call run_sql,sql/transform/build_curated_model.sql)

# Create/refresh semantic view object used by Cortex Analyst tool binding.
semantic-view:
	@echo "Creating semantic view for Cortex Analyst tool binding"
	$(call run_sql,models/DMEPOS_SEMANTIC_VIEW.sql)

# ------------------------------
# Search
# ------------------------------

# Create all search services, including PDF search path.
search:
	@echo "Creating Cortex Search services (HCPCS, devices, providers, PDFs)"
	@echo "Note: this step can take a few minutes while search indexing/embedding initializes. Do not stop the run."
	$(call run_sql,sql/search/cortex_search_hcpcs.sql)
	$(call run_sql,sql/search/cortex_search_devices.sql)
	$(call run_sql,sql/search/cortex_search_providers.sql)

	# Keep PDF service in main search flow to reduce setup friction.
	$(MAKE) search-pdf

# Create PDF stage and enable directory metadata.
pdf-setup:
	@echo "Preparing PDF stage"
	$(call run_sql,sql/setup/pdf_stage_setup.sql)

# Upload local PDF files to @SEARCH.PDF_STAGE when files exist.
pdf-upload: pdf-setup
	@echo "Uploading local PDFs from pdf/cms_manuals to @SEARCH.PDF_STAGE (if present)"
	@if [ -d "pdf/cms_manuals" ] && find "pdf/cms_manuals" -type f -name '*.pdf' | grep -q .; then \
		$(SNOW_CMD) -q "USE ROLE MEDICARE_POS_INTELLIGENCE; USE DATABASE MEDICARE_POS_DB; USE SCHEMA SEARCH; PUT 'file://$(CURDIR)/pdf/cms_manuals/*.pdf' @SEARCH.PDF_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"; \
	else \
		echo "No local PDFs found in pdf/cms_manuals. Skipping upload."; \
		echo "Add PDFs there or upload in Snowsight, then rerun make search-pdf."; \
	fi

# Parse staged PDFs and create/refresh PDF search service.
search-pdf: pdf-upload
	@echo "Creating PDF search service"
	$(call run_sql,sql/search/cortex_search_pdf.sql)

# Run smoke checks against PDF search service.
pdf-validate:
	@echo "Validating PDF search"
	$(call run_sql,sql/setup/pdf_search_validation.sql)

# ------------------------------
# Governance + Intelligence
# ------------------------------

# Apply lightweight metadata objects for demo governance flow.
metadata-demo:
	@echo "Applying demo metadata"
	$(call run_sql,sql/governance/metadata_demo.sql)

# Run lightweight profiling checks for demo governance flow.
profile-demo:
	@echo "Running demo profiling"
	$(call run_sql,sql/governance/profile_demo.sql)

# Run demo metadata + profiling together.
governance-demo: metadata-demo profile-demo

# One-time admin bootstrap for AI Observability grants (ACCOUNTADMIN required).
observability-bootstrap:
	@echo "Bootstrapping AI observability access (one-time, requires ACCOUNTADMIN)"
	$(call run_sql,sql/observability/01_grant_all_privileges.sql)

# Build observability trust-layer objects using runtime role grants.
observability:
	@echo "Building observability objects (governance view/proc + task + quality layer)"
	@echo "If this is a fresh account, run 'make observability-bootstrap' once first."
	$(call run_sql,sql/observability/02_create_governance_objects.sql)
	$(call run_sql,sql/observability/03_create_scheduled_task.sql)
	$(call run_sql,sql/observability/04_create_quality_tables.sql)

# Create query instrumentation tables and seed eval prompts.
instrumentation:
	@echo "Creating instrumentation tables"
	$(call run_sql,sql/intelligence/instrumentation.sql)
	$(call run_sql,sql/intelligence/eval_seed.sql)

# Build knowledge graph objects used by intelligence layer.
knowledge-graph:
	@echo "Building knowledge graph"
	$(call run_sql,sql/intelligence/knowledge_graph.sql)

# Create business-question validation framework tables/views.
validation:
	@echo "Creating validation framework"
	$(call run_sql,sql/intelligence/validation_framework.sql)

# Apply post-deploy grants for services and runtime roles.
grants:
	@echo "Applying grants"
	$(call run_sql,sql/setup/apply_grants.sql)

# Full governance/profiling targets
# Apply full metadata and quality governance objects.
metadata:
	@echo "Applying full metadata and quality setup"
	$(call run_sql,sql/governance/metadata_and_quality.sql)

# Run full profiling workload and store profile metrics.
profile:
	@echo "Running full profiling"
	$(call run_sql,sql/governance/run_profiling.sql)

# ------------------------------
# Agent 
# ------------------------------
# Create Cortex Agent after semantic view and search services exist.
agent: semantic-view search
	@echo "Creating Cortex Agent"
	@echo "Prereq: curated model exists (run 'make transform' first)"
	$(call run_sql,sql/agent/cortex_agent.sql)


# ------------------------------
# Test 
# ------------------------------
# Execute semantic regression checks and persist PASS/FAIL results.
test:
	@echo "Running semantic model tests"
	$(call run_sql,sql/intelligence/semantic_model_tests.sql)

tests: test
verify: test

# Clear semantic test result table for a fresh run.
clean-tests:
	@echo "Clearing semantic test results"
	$(SNOW_CMD) -q "TRUNCATE TABLE INTELLIGENCE.SEMANTIC_TEST_RESULTS;"

# ------------------------------
# Orchestrated flows
# ------------------------------
# Run demo path end-to-end for learning workflow.
demo: data setup load transform search governance-demo instrumentation validation observability grants
	@echo "Demo deployment complete"
	@echo "Next: make knowledge-graph, make agent, make test"

# Run full deploy path including validation, tests, and agent.
deploy: demo knowledge-graph test agent
	@echo "Full deployment complete"

deploy-all: TARGET=deploy
deploy-all: log

# Wrapper target to run selected TARGET and write console+file logs.
log:
	@echo "Running target: $(TARGET)"
	@echo "Logging to: $(LOG_FILE)"
	@bash -lc 'set -o pipefail; mkdir -p "$(LOG_DIR)"; $(MAKE) $(TARGET) 2>&1 | tee "$(LOG_FILE)"'

# ------------------------------
# Cleanup
# ------------------------------

# Drop deployed database objects, warehouse, and roles after confirmation.
teardown:
	@echo "WARNING: this will delete MEDICARE_POS_DB, MEDICARE_POS_WH, roles, and all deployed objects"
	@read -p "Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		$(call run_sql,sql/cleanup/teardown.sql); \
		echo "Teardown complete"; \
	else \
		echo "Teardown canceled"; \
	fi

reset: teardown

# ------------------------------
# Help
# ------------------------------

# Print quick command reference for common targets.
help:
	@echo ""
	@echo "Core targets"
	@echo "  make demo         End-to-end demo flow"
	@echo "  make transform    Build curated + analytics model"
	@echo "  make search       Create HCPCS/device/provider/PDF search services"
	@echo "  make semantic-view Create semantic view object from models/DMEPOS_SEMANTIC_VIEW.sql"
	@echo "  make agent        Create Cortex Agent (builds semantic view + search first)"
	@echo "  make test         Run semantic model tests"
	@echo "  make reset        Full teardown"
	@echo ""
	@echo "Useful extras"
	@echo "  make stage-raw    Upload local source files to RAW stages"
	@echo "  make deploy-all   Run full deploy and stream output to logs/ (default)"
	@echo "  make log TARGET=demo Run any target with live log capture"
	@echo "  make pdf-setup    Prepare PDF stage (manual refresh path)"
	@echo "  make pdf-upload   Upload local pdf/cms_manuals/*.pdf to stage"
	@echo "  make search-pdf   Recreate PDF search service only"
	@echo "  make pdf-validate Validate PDF search"
	@echo "  make deploy       Demo + observability + knowledge graph + tests + agent"
	@echo "  make observability-bootstrap  One-time ACCOUNTADMIN observability grants"
	@echo "  make observability            Build observability trust-layer objects"
