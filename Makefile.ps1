param(
    [Parameter(Position = 0)]
    [string]$Target = "help",
    [string]$Connection = "sf_int",
    [string]$RunTarget = "demo",
    [string]$LogDir = "logs",
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$script:Snow = if ($env:SNOW) { $env:SNOW } else { "snow" }
$script:RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Set-Location $script:RepoRoot

function Invoke-SqlFile {
    param([string]$FilePath)
    # Run a SQL file with the configured Snowflake CLI connection.
    & $script:Snow sql -c $Connection -f $FilePath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed running SQL file: $FilePath"
    }
}

function Invoke-SqlQuery {
    param([string]$QueryText)
    # Run an inline SQL query with the configured Snowflake CLI connection.
    & $script:Snow sql -c $Connection -q $QueryText
    if ($LASTEXITCODE -ne 0) {
        throw "Failed running SQL query."
    }
}

function Invoke-Target {
    param([string]$Name)

    switch ($Name.ToLowerInvariant()) {
        "data" {
            # Download CMS/FDA source files to local data/ folder.
            Write-Host "Downloading source data"
            & $Python data/dmepos_referring_provider_download.py --max-rows 1000000
            if ($LASTEXITCODE -ne 0) { throw "Failed running dmepos_referring_provider_download.py" }

            if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
                throw "bash is required for data/data_download.sh on Windows. Use Git Bash/WSL or download files manually into data/."
            }
            & bash data/data_download.sh
            if ($LASTEXITCODE -ne 0) { throw "Failed running data/data_download.sh" }
        }
        "setup" {
            # Create Snowflake role, warehouse, database, schemas, and base grants.
            Write-Host "Setting up Snowflake infrastructure"
            Invoke-SqlFile "sql/setup/setup_user_and_roles.sql"
        }
        "stage-raw" {
            # Upload local source files to RAW stages.
            Write-Host "Uploading local raw files to Snowflake internal stages"
            if (-not (Test-Path "data/dmepos_referring_provider.json")) {
                throw "Missing data/dmepos_referring_provider.json. Run '.\Makefile.ps1 data' first."
            }
            if (-not (Test-Path "data/gudid_delimited")) {
                throw "Missing data/gudid_delimited/. Run '.\Makefile.ps1 data' first."
            }
            Invoke-SqlFile "sql/ingestion/stage_raw_files.sql"
        }
        "load" {
            # Load staged files into RAW tables.
            Write-Host "Loading raw data"
            Invoke-Target "stage-raw"
            Invoke-SqlFile "sql/ingestion/load_raw_data.sql"
        }
        "transform" {
            # Build curated and analytics model objects.
            Write-Host "Building curated + analytics model"
            Invoke-SqlFile "sql/transform/build_curated_model.sql"
        }
        "semantic-view" {
            # Create semantic view used by the SQL-defined agent.
            Write-Host "Creating semantic view for Cortex Analyst tool binding"
            Invoke-SqlFile "models/DMEPOS_SEMANTIC_VIEW.sql"
        }
        "search" {
            # Create all search services, including PDF service path.
            Write-Host "Creating Cortex Search services (HCPCS, devices, providers, PDFs)"
            Write-Host "Note: this step can take a few minutes while search indexing/embedding initializes. Do not stop the run."
            Invoke-SqlFile "sql/search/cortex_search_hcpcs.sql"
            Invoke-SqlFile "sql/search/cortex_search_devices.sql"
            Invoke-SqlFile "sql/search/cortex_search_providers.sql"
            Invoke-Target "search-pdf"
        }
        "pdf-setup" {
            # Create PDF stage and enable directory metadata.
            Write-Host "Preparing PDF stage"
            Invoke-SqlFile "sql/setup/pdf_stage_setup.sql"
        }
        "pdf-upload" {
            # Upload local PDFs to @SEARCH.PDF_STAGE if files exist.
            Invoke-Target "pdf-setup"
            Write-Host "Uploading local PDFs from pdf/cms_manuals to @SEARCH.PDF_STAGE (if present)"
            $pdfDir = Join-Path $script:RepoRoot "pdf/cms_manuals"
            $pdfFiles = Get-ChildItem -Path $pdfDir -Filter "*.pdf" -File -ErrorAction SilentlyContinue
            if ($pdfFiles -and $pdfFiles.Count -gt 0) {
                $normalizedDir = ($pdfDir -replace "\\", "/")
                $query = "USE ROLE MEDICARE_POS_INTELLIGENCE; USE DATABASE MEDICARE_POS_DB; USE SCHEMA SEARCH; PUT 'file://$normalizedDir/*.pdf' @SEARCH.PDF_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"
                Invoke-SqlQuery $query
            } else {
                Write-Host "No local PDFs found in pdf/cms_manuals. Skipping upload."
                Write-Host "Add PDFs there or upload in Snowsight, then rerun '.\Makefile.ps1 search-pdf'."
            }
        }
        "search-pdf" {
            # Parse staged PDFs and recreate PDF search service.
            Invoke-Target "pdf-upload"
            Write-Host "Creating PDF search service"
            Invoke-SqlFile "sql/search/cortex_search_pdf.sql"
        }
        "pdf-validate" {
            # Validate PDF search service with sample checks.
            Write-Host "Validating PDF search"
            Invoke-SqlFile "sql/setup/pdf_search_validation.sql"
        }
        "metadata-demo" {
            # Apply lightweight metadata setup for demo flow.
            Write-Host "Applying demo metadata"
            Invoke-SqlFile "sql/governance/metadata_demo.sql"
        }
        "profile-demo" {
            # Run lightweight profiling setup for demo flow.
            Write-Host "Running demo profiling"
            Invoke-SqlFile "sql/governance/profile_demo.sql"
        }
        "governance-demo" {
            # Run demo governance chain (metadata + profiling).
            Invoke-Target "metadata-demo"
            Invoke-Target "profile-demo"
        }
        "instrumentation" {
            # Create instrumentation tables and eval seed set.
            Write-Host "Creating instrumentation tables"
            Invoke-SqlFile "sql/intelligence/instrumentation.sql"
            Invoke-SqlFile "sql/intelligence/eval_seed.sql"
        }
        "knowledge-graph" {
            # Build knowledge graph objects.
            Write-Host "Building knowledge graph"
            Invoke-SqlFile "sql/intelligence/knowledge_graph.sql"
        }
        "validation" {
            # Create validation framework tables/views.
            Write-Host "Creating validation framework"
            Invoke-SqlFile "sql/intelligence/validation_framework.sql"
        }
        "observability-bootstrap" {
            # One-time admin bootstrap for AI Observability grants.
            Write-Host "Bootstrapping AI observability access (one-time, requires ACCOUNTADMIN)"
            Invoke-SqlFile "sql/observability/01_grant_all_privileges.sql"
        }
        "observability" {
            # Build observability trust-layer objects using runtime role grants.
            Write-Host "Building observability objects (governance view/proc + task + quality layer)"
            Write-Host "If this is a fresh account, run '.\\Makefile.ps1 observability-bootstrap' once first."
            Invoke-SqlFile "sql/observability/02_create_governance_objects.sql"
            Invoke-SqlFile "sql/observability/03_create_scheduled_task.sql"
            Invoke-SqlFile "sql/observability/04_create_quality_tables.sql"
        }
        "grants" {
            # Apply post-deployment grants.
            Write-Host "Applying grants"
            Invoke-SqlFile "sql/setup/apply_grants.sql"
        }
        "metadata" {
            # Apply full governance metadata + quality objects.
            Write-Host "Applying full metadata and quality setup"
            Invoke-SqlFile "sql/governance/metadata_and_quality.sql"
        }
        "profile" {
            # Run full data profiling workload.
            Write-Host "Running full profiling"
            Invoke-SqlFile "sql/governance/run_profiling.sql"
        }
        "agent" {
            # Create agent after semantic view and search services exist.
            Invoke-Target "semantic-view"
            Invoke-Target "search"
            Write-Host "Creating Cortex Agent"
            Write-Host "Prereq: curated model exists (run '.\Makefile.ps1 transform' first)"
            Invoke-SqlFile "sql/agent/cortex_agent.sql"
        }
        "test" {
            # Run semantic regression checks.
            Write-Host "Running semantic model tests"
            Invoke-SqlFile "sql/intelligence/semantic_model_tests.sql"
        }
        "tests" {
            # Alias for test.
            Invoke-Target "test"
        }
        "verify" {
            # Alias for test.
            Invoke-Target "test"
        }
        "clean-tests" {
            # Clear semantic test results table.
            Write-Host "Clearing semantic test results"
            Invoke-SqlQuery "TRUNCATE TABLE INTELLIGENCE.SEMANTIC_TEST_RESULTS;"
        }
        "demo" {
            # Run end-to-end demo deployment chain.
            Invoke-Target "data"
            Invoke-Target "setup"
            Invoke-Target "load"
            Invoke-Target "transform"
            Invoke-Target "search"
            Invoke-Target "governance-demo"
            Invoke-Target "instrumentation"
            Invoke-Target "validation"
            Invoke-Target "observability"
            Invoke-Target "grants"
            Write-Host "Demo deployment complete"
            Write-Host "Next: .\Makefile.ps1 knowledge-graph, .\Makefile.ps1 agent, .\Makefile.ps1 test"
        }
        "deploy" {
            # Run full deployment chain including validation/tests/agent.
            Invoke-Target "demo"
            Invoke-Target "knowledge-graph"
            Invoke-Target "test"
            Invoke-Target "agent"
            Write-Host "Full deployment complete"
        }
        "deploy-all" {
            # Run deploy with log capture by default.
            $previousRunTarget = $RunTarget
            $script:RunTarget = "deploy"
            try {
                Invoke-Target "log"
            } finally {
                $script:RunTarget = $previousRunTarget
            }
        }
        "log" {
            # Execute target and tee output to logs/<target>_<timestamp>.log.
            if ($RunTarget.ToLowerInvariant() -eq "log") {
                throw "RunTarget cannot be 'log'."
            }

            New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
            $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $logFile = Join-Path $LogDir "$RunTarget`_$stamp.log"
            Write-Host "Running target: $RunTarget"
            Write-Host "Logging to: $logFile"

            $pwshCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
            & $pwshCmd -NoProfile -ExecutionPolicy Bypass -File $MyInvocation.MyCommand.Path $RunTarget -Connection $Connection -Python $Python -LogDir $LogDir 2>&1 | Tee-Object -FilePath $logFile
            if ($LASTEXITCODE -ne 0) {
                throw "Target '$RunTarget' failed. See $logFile"
            }
        }
        "teardown" {
            # Drop deployed objects after explicit confirmation.
            Write-Host "WARNING: this will delete MEDICARE_POS_DB, MEDICARE_POS_WH, roles, and all deployed objects"
            $confirm = Read-Host "Type 'yes' to continue"
            if ($confirm -eq "yes") {
                Invoke-SqlFile "sql/cleanup/teardown.sql"
                Write-Host "Teardown complete"
            } else {
                Write-Host "Teardown canceled"
            }
        }
        "reset" {
            # Alias for teardown.
            Invoke-Target "teardown"
        }
        "help" {
            # Print target and usage summary for PowerShell runner.
            Write-Host ""
            Write-Host "PowerShell Runner (Windows)"
            Write-Host "  .\Makefile.ps1 demo"
            Write-Host "  .\Makefile.ps1 deploy-all"
            Write-Host "  .\Makefile.ps1 log -RunTarget demo"
            Write-Host ""
            Write-Host "Core targets"
            Write-Host "  demo, deploy, deploy-all, transform, search, semantic-view, agent, test, reset"
            Write-Host ""
            Write-Host "Useful extras"
            Write-Host "  data, setup, stage-raw, load, metadata-demo, profile-demo, governance-demo"
            Write-Host "  instrumentation, validation, observability-bootstrap, observability, knowledge-graph, grants"
            Write-Host "  observability-bootstrap is a one-time admin bootstrap per environment"
            Write-Host "  pdf-setup, pdf-upload, search-pdf, pdf-validate"
            Write-Host "  metadata, profile, clean-tests, log"
            Write-Host ""
            Write-Host "Connection override examples"
            Write-Host "  .\Makefile.ps1 demo -Connection my_conn"
            Write-Host "  `$env:SNOW='snow'; .\Makefile.ps1 test -Connection sf_int"
        }
        default {
            throw "Unknown target: $Name. Run '.\Makefile.ps1 help' to list targets."
        }
    }
}

try {
    Invoke-Target $Target
    exit 0
} catch {
    Write-Error $_
    exit 1
}
