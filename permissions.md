dbt SQL Server Permission Model — Guiding Principle
Overview
This project uses dbt Core to build, test, and deploy data models on SQL Server.
To maintain a secure and auditable environment, dbt runs under a domain‑managed gMSA on an application VM, connecting to SQL Server using Kerberos authentication.

The permission model follows a strict principle of least privilege:
dbt receives only the minimum rights required to create and manage objects inside its own schemas, and nothing more.

Guiding Principle
dbt must have full control over the schemas it manages, and zero control over anything else.

SQL Server does not provide a single “write” permission that covers all operations dbt performs.
To function correctly, dbt needs to be able to:

create and replace tables

create and replace views

drop and rebuild objects

run incremental logic

run tests that generate SQL

create temporary tables

optionally create ephemeral PR schemas during CI

These operations require a combination of object‑level permissions that SQL Server only grants through CONTROL on a schema.

By granting CONTROL only on dbt‑managed schemas, we ensure:

dbt can fully manage its own objects

dbt cannot modify or read objects in other schemas

no database‑wide or server‑level permissions are required

the blast radius is tightly contained

the model remains compliant with least‑privilege security standards

Permission Summary
Database‑level (minimum required)
CONNECT — establish a session

SELECT — required for dbt tests

CREATE TABLE — required for temp tables during tests

CREATE SCHEMA — only if CI creates ephemeral PR schemas

Schema‑level (dbt‑managed schemas only)
Grant CONTROL on:

raw

staging

int

reporting

prod

*_pr_<number> (ephemeral CI schemas, if used)

Example:

Code
GRANT CONTROL ON SCHEMA::staging TO [DOMAIN\my-dbt-gmsa$];
No permissions granted on any other schemas
Why CONTROL is the Minimum
dbt needs to perform DDL and DML operations that SQL Server does not group under a single permission.
Without CONTROL, dbt would require a long list of granular permissions (CREATE VIEW, ALTER, DROP, INSERT, UPDATE, DELETE, REFERENCES, etc.), which is brittle and still incomplete.

CONTROL is the smallest permission that:

enables all dbt operations

applies only to the specific schema

avoids database‑wide privileges

keeps the environment secure and predictable

Security Benefits
Strong isolation between dbt and other workloads

No db_owner, no ALTER ANY SCHEMA, no server‑level rights

gMSA provides automatic password rotation and full auditability

CI ephemeral schemas remain isolated and safe

dbt retains full functionality without over‑privilege
