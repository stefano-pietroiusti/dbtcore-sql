# ======================================================================
# Unified Reconciliation Output Table Schema (Metadata‑Only)
# ======================================================================

Table Name:
    reconciliation_unified

Purpose:
    A metadata‑only mismatch ledger that records reconciliation outcomes
    between BIANSystem and CRM across all BIAN domains and entities.
    This table contains NO attribute values and NO PII.

----------------------------------------------------------------------
Columns
----------------------------------------------------------------------

1. domain (STRING)
   - The BIAN service domain (e.g., Party, Product, Agreement).
   - Drives grouping and filtering in dashboards.

2. entity (STRING)
   - The BIAN business object (e.g., Customer, Address, Device).
   - Combined with domain, identifies the reconciliation model.

3. primary_key_hash (STRING)
   - A deterministic hash of all key attributes for the record.
   - Ensures no sensitive CRM or BIANSystem values appear.
   - Used for grouping mismatches belonging to the same record.

4. attribute_name (STRING)
   - The attribute that failed reconciliation.
   - Comes directly from metadata (bian_attribute).

5. reconciliation_type (STRING)
   - The comparison rule applied.
   - Examples: EXACT, NORMALIZED, DATE_ONLY.
   - Sourced from bian_reconciliation_types.csv.

6. match_status (STRING)
   - One of:
       - MATCH
       - MISMATCH
       - MISSING_IN_BIANSYSTEM
       - MISSING_IN_CRM
   - Indicates the reconciliation outcome for the attribute.

7. mismatch_reason (STRING)
   - Human‑readable explanation of the mismatch.
   - Examples:
       - "normalized comparison failed"
       - "missing CRM record"
       - "missing BIANSystem record"
       - "date-only comparison failed"
   - Empty/null for MATCH rows (optional).

8. run_timestamp (TIMESTAMP)
   - Timestamp of the reconciliation run.
   - Supports incremental loads and auditability.

----------------------------------------------------------------------
Optional Columns (if required)
----------------------------------------------------------------------

9. domain_entity_key (STRING)
   - Optional composite key: domain + entity.
   - Useful for partitioning or clustering.

10. reconciliation_run_id (STRING)
    - Optional unique ID for each reconciliation batch.

----------------------------------------------------------------------
Constraints & Notes
----------------------------------------------------------------------

- No BIANSystem values are stored.
- No CRM values are stored.
- No PII is stored.
- No raw attributes or business data appear in this table.
- All joins and comparisons are performed upstream using metadata.
- This table is safe for unrestricted dashboard consumption.

----------------------------------------------------------------------
Example Rows (Metadata‑Only)
----------------------------------------------------------------------

domain: Party
entity: Customer
primary_key_hash: 8f3a9c1e2b...
attribute_name: email
reconciliation_type: NORMALIZED
match_status: MISMATCH
mismatch_reason: "normalized comparison failed"
run_timestamp: 2026‑02‑18T04:00:00Z

domain: Party
entity: Customer
primary_key_hash: 8f3a9c1e2b...
attribute_name: phone
reconciliation_type: EXACT
match_status: MATCH
mismatch_reason: null
run_timestamp: 2026‑02‑18T04:00:00Z

----------------------------------------------------------------------
Summary
----------------------------------------------------------------------

The unified reconciliation output table:
- Stores metadata only
- Contains no values from BIANSystem or CRM
- Supports all BIAN domains and entities
- Handles polymorphic keys (partyReferenceId → owner/address/did)
- Enables sponsor‑grade auditability and monitoring
- Scales horizontally as new domains/entities are added

# ======================================================================
# END OF SCHEMA
# ======================================================================


-- =====================================================================
-- Unified Reconciliation Output Table (Metadata‑Only)
-- =====================================================================

CREATE TABLE reconciliation_unified (
    -- BIAN domain (e.g., Party, Product, Agreement)
    domain                  VARCHAR(100)        NOT NULL,

    -- BIAN entity (e.g., Customer, Address, Device)
    entity                  VARCHAR(100)        NOT NULL,

    -- Deterministic hash of all key attributes (no PII)
    primary_key_hash        VARCHAR(200)        NOT NULL,

    -- Attribute that was compared (e.g., email, phone, postcode)
    attribute_name          VARCHAR(200)        NOT NULL,

    -- Comparison rule applied (EXACT, NORMALIZED, DATE_ONLY, etc.)
    reconciliation_type     VARCHAR(50)         NOT NULL,

    -- MATCH, MISMATCH, MISSING_IN_BIANSYSTEM, MISSING_IN_CRM
    match_status            VARCHAR(50)         NOT NULL,

    -- Human‑readable explanation of mismatch (no values)
    mismatch_reason         VARCHAR(500),

    -- Timestamp of reconciliation run
    run_timestamp           TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Optional performance optimizations (warehouse‑dependent):
-- CREATE INDEX idx_recon_domain_entity ON reconciliation_unified(domain, entity);
-- CREATE INDEX idx_recon_pk_hash ON reconciliation_unified(primary_key_hash);
-- CREATE INDEX idx_recon_status ON reconciliation_unified(match_status);
