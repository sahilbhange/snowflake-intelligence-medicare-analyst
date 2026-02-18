-- Create daily task to populate AI governance table from observability events.

USE ROLE MEDICARE_POS_INTELLIGENCE;
USE DATABASE MEDICARE_POS_DB;
USE SCHEMA GOVERNANCE;

-- Create scheduled task.

CREATE OR REPLACE TASK GOVERNANCE.DAILY_AI_GOVERNANCE_REFRESH
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 2 * * * America/Los_Angeles'  -- Daily at 2 AM PT
    COMMENT = 'Auto-populate AI governance data from last 7 days of AI Observability events'
AS
    CALL GOVERNANCE.POPULATE_AI_GOVERNANCE(7);

-- Task is created suspended by default; resume to activate.
ALTER TASK GOVERNANCE.DAILY_AI_GOVERNANCE_REFRESH RESUME;

-- Verify task and recent task history.

SHOW TASKS LIKE 'DAILY_AI_GOVERNANCE_REFRESH' IN SCHEMA GOVERNANCE;

-- Check task history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
    TASK_NAME => 'DAILY_AI_GOVERNANCE_REFRESH'
))
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;

-- Optional manual execution/suspend commands.

-- If you need to run manually before scheduled time:
-- EXECUTE TASK GOVERNANCE.DAILY_AI_GOVERNANCE_REFRESH;

-- To suspend task (stop auto-execution):
-- ALTER TASK GOVERNANCE.DAILY_AI_GOVERNANCE_REFRESH SUSPEND;
