================================================================================
CENTRALISED LOGGING & MONITORING – README
================================================================================

Overview
--------
This document describes the centralised logging and monitoring pattern used
across the reconciliation engine. All components (PowerShell, Python, dbt, SQL
stored procedures) emit structured log events into a single, stable logging
surface hosted in the DB database.

This approach ensures:
- Consistent logging across all technologies
- A minimal sensitive data footprint
- A single source of truth for operational monitoring
- Sponsor-grade auditability and traceability
- Clean integration with Control-M


Why Centralise Logging?
-----------------------
The reconciliation engine spans multiple runtimes and VMs:

- PowerShell wrappers on the App VM
- Python ingestion and utility scripts on the App VM
- dbt transformations on the App VM
- SQL stored procedures on the SQL VM

Without centralisation, logs become fragmented across machines, formats, and
filesystems. This makes troubleshooting difficult and increases operational
risk.

By centralising logging into DB, we achieve:
- Cross-component correlation via a shared RunId
- Deterministic, queryable logs
- Consistent retention and masking rules
- A single pane of glass for Control-M and support teams


Architecture Summary
--------------------
All components call a single stored procedure:

    monitoring.LogEvent

This stored procedure inserts structured log events into:

    DB.monitoring.LogEvents

The stored procedure acts as the logging API for the entire platform. Scripts
and jobs never insert directly into the table.


Logging Table Structure
-----------------------
Table: DB.monitoring.LogEvents

Columns:
- LogId (identity)
- TimestampUtc
- ComponentName
- RunId
- Level (INFO, WARN, ERROR)
- Message
- PayloadJson (optional)
- HostName


Stored Procedure: monitoring.LogEvent
-------------------------------------
The stored procedure accepts the following parameters:

- @ComponentName
- @RunId
- @Level
- @Message
- @PayloadJson (optional)

It inserts a row into LogEvents with SYSUTCDATETIME() and HOST_NAME().

This procedure is the single entry point for all logging.


Logging From PowerShell
-----------------------
PowerShell scripts call the logging sproc using sqlcmd:

    EXEC monitoring.LogEvent
        @ComponentName = 'powershell.wrapper',
        @RunId = $RunId,
        @Level = 'INFO',
        @Message = 'Starting Python ingestion',
        @PayloadJson = '{}';


Logging From Python
-------------------
Python scripts call the logging sproc using pyodbc or sqlalchemy:

    cursor.execute("""
        EXEC monitoring.LogEvent
            @ComponentName = ?,
            @RunId = ?,
            @Level = ?,
            @Message = ?,
            @PayloadJson = ?;
    """, (...))


Logging From dbt
----------------
dbt uses run_query() inside on-run-start and on-run-end hooks:

    on-run-start:
      - "{{ run_query(\"EXEC monitoring.LogEvent @ComponentName='dbt', @RunId='{{ run_started_at }}', @Level='INFO', @Message='dbt run started'\") }}"

This provides visibility into dbt execution at the orchestration level.


Logging From SQL Stored Procedures
----------------------------------
SQL sprocs (e.g., monitoring.Check_CRMRecon_Health) log their own events:

    EXEC monitoring.LogEvent
        @ComponentName = 'sql.Check_CRMRecon_Health',
        @RunId = @RunId,
        @Level = 'INFO',
        @Message = 'Starting health checks';


RunId Convention
----------------
All components participating in a single reconciliation run share the same RunId.

Recommended format:
- ISO-8601 timestamp
- Or Control-M job run identifier

Example:
    2026-02-12T10:00:00Z


Retention Policy
----------------
The platform enforces a **30-day retention policy** for all log events.

- LogEvents older than 30 days are purged automatically by a scheduled job.
- This ensures the logging surface remains lightweight and compliant.
- Only operational metadata is retained; no sensitive business data is stored.
- The retention window aligns with reconciliation audit requirements.

Because all logs flow through a single table, retention is simple, predictable,
and centrally managed.


Benefits of the Stored Procedure Approach
-----------------------------------------
- Centralised control of logging behaviour
- Consistent formatting and validation
- Ability to evolve logging without touching scripts
- Easy to add:
  - masking rules
  - severity filtering
  - retention policies
  - correlation IDs
- Clean separation between producers and storage
- Fully auditable and sponsor-grade


Security Considerations
-----------------------
- No sensitive data should be logged in Message or PayloadJson.
- PayloadJson is intended for metadata, counts, and diagnostics only.
- Access to LogEvents is restricted to operational and support roles.


Summary
-------
This centralised logging pattern provides a unified, stable, and auditable
logging surface for the entire reconciliation engine. It simplifies operations,
reduces risk, and ensures consistent behaviour across PowerShell, Python, dbt,
and SQL components.

================================================================================
END OF README
================================================================================
