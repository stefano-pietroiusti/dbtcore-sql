# Dynamic BIAN Domain Reconciliation (BIANSystem ↔ CRM)

## 1. Overview

This document describes the architecture and workflow for a **dynamic, metadata-driven reconciliation engine** between:

- **BIANSystem** → the system that produces BIAN-aligned data  
- **CRM** → the operational source system providing customer/party data  

The objective is to reconcile BIANSystem outputs against CRM **without writing entity-specific SQL**.  
All reconciliation logic is generated dynamically using metadata.

### What the Engine Does

The reconciliation engine:
- ✅ Identifies mismatches between BIANSystem and CRM
- ✅ Supports all BIAN service domains and business objects
- ✅ Uses metadata to drive join logic, comparison logic, and mismatch reporting
- ✅ Produces a unified reconciliation output table for all domains
- ✅ Stores **no values** in the unified table (metadata-only mismatch ledger)

### Reconciliation Outputs

The reconciliation layer produces:

- **Unified mismatch table** containing only metadata (no attribute values)
- **One reconciliation model** per BIAN domain and entity
- **Macro framework** that dynamically builds join rules, comparison logic, and match status

**Note:** Actual value investigation is performed directly against staging models and is not stored in reporting schemas.

This design ensures **scalability, auditability, and consistency** across all BIAN domains and entities.

---

## 2. Metadata Inputs

### 2.1 bian_mappings.csv

Defines attribute-level mappings between BIANSystem and CRM.

**Required columns:**

| Column | Description |
|--------|-------------|
| `domain` | BIAN service domain |
| `entity` | BIAN business object |
| `bian_attribute` | Attribute name in BIANSystem |
| `crm_attribute` | Attribute name in CRM |
| `is_key` | Key indicator (Y/N) |
| `mapping_rule` | Optional transformation rule |
| `is_active` | Active flag (Y/N) |

**Purpose:**
- Defines how BIANSystem attributes map to CRM attributes
- Identifies key attributes using `is_key = 'Y'`
- Provides mapping rules for transformation logic

### 2.2 bian_reconciliation_types.csv

Defines how attributes should be compared.

**Required columns:**

| Column | Description |
|--------|-------------|
| `reconciliation_type` | Type of comparison (EXACT, NORMALIZED, DATE_ONLY, etc.) |
| `comparison_rule` | SQL-level comparison logic |
| `description` | Description of reconciliation type |

**Common reconciliation types:**
- `EXACT` - Exact match required
- `NORMALIZED` - Trimmed, lowercased comparison
- `DATE_ONLY` - Compare date part only
- `NUMERIC_TOLERANCE` - Allow minor numeric differences

---

## 3. Normalized Metadata Model

Raw seeds are transformed into a **normalized metadata table** (`bian_mappings_normalized`) with:

**Core columns:**
- `domain`
- `entity`
- `bian_attribute`
- `crm_attribute`
- `is_key`
- `crm_key_type` (owner, address, did, generic)
- `reconciliation_type`
- `mapping_rule`
- `is_active`

This table is the **single source of truth** for all reconciliation logic.

---

## 4. Transformation Macros

### 4.1 classify_crm_key_type(column_name)

Macro that assigns CRM key types used for join logic.

**Classification rules:**

| Column Pattern | CRM Key Type |
|----------------|--------------|
| `owner_id` or `owner_type_id` | `owner` |
| `address_id` | `address` |
| `did` | `did` |
| All others | `generic` |

**Example:**
```jinja
{% macro classify_crm_key_type(column_name) %}
    case
        when lower('{{ column_name }}') in ('owner_id', 'owner_type_id') then 'owner'
        when lower('{{ column_name }}') = 'address_id' then 'address'
        when lower('{{ column_name }}') = 'did' then 'did'
        else 'generic'
    end
{% endmacro %}
```

### 4.2 transform_bian_mappings()

Converts raw seed rows into normalized metadata.

**Transformation steps:**
1. Filters active rows (`is_active = 'Y'`)
2. Splits BIANSystem vs CRM attributes
3. Aggregates into one row per mapped attribute
4. Applies key type classification via `classify_crm_key_type()`
5. Joins reconciliation types

**Output model:** `bian_mappings_normalized`

---

## 5. Reconciliation Architecture

Reconciliation runs per **domain + entity** pair.

### 5.1 Inputs

- BIANSystem staging model: `stg_biansystem_<domain>_<entity>`
- CRM staging model: `stg_crm_<domain>_<entity>`
- Normalized metadata: `bian_mappings_normalized`

### 5.2 Outputs

A unified reconciliation table containing **metadata only**, not values:
- domain
- entity
- source_system
- target_system
- primary_key_hash
- attribute_name
- reconciliation_type
- match_status
- mismatch_reason
- run_timestamp

---

## 6. Dynamic Join Logic

### 6.1 Key Selection

Keys are attributes where `is_key = 'Y'`.

### 6.2 CRM Key Type Handling

CRM keys may require special handling:

| CRM Key Type | Join Logic |
|--------------|------------|
| `owner` | Join on `owner_id + owner_type_id` |
| `address` | Join on `address_id` |
| `did` | Join on `did` |
| `generic` | Direct attribute join |

### 6.3 build_join_conditions() Macro

Reads metadata and produces SQL join conditions dynamically.

**File:** `macros/reconciliation/build_join_conditions.sql`

```jinja
{% macro build_join_conditions(mapping_rows, bian_alias='bian', crm_alias='crm') %}
    {# 
      mapping_rows: list of mapping records for a given domain/entity
      Each row should expose:
        - bian_attribute
        - crm_attribute
        - is_key
        - crm_key_type (owner, address, did, generic)
    #}

    {# Collect individual join predicates #}
    {% set join_predicates = [] %}

    {% for row in mapping_rows %}
        {% if row.is_key is string and row.is_key | lower == 'y' %}

            {% set bian_col = row.bian_attribute %}
            {% set crm_col = row.crm_attribute %}
            {% set key_type = (row.crm_key_type or 'generic') | lower %}

            {% if key_type == 'owner' %}
                {# Owner-based join: composite key #}
                {% set predicate = bian_alias ~ '.' ~ bian_col ~ ' = ' ~ crm_alias ~ '.owner_id' %}
                {% do join_predicates.append(predicate) %}

            {% elif key_type == 'address' %}
                {# Address-based join #}
                {% set predicate = bian_alias ~ '.' ~ bian_col ~ ' = ' ~ crm_alias ~ '.address_id' %}
                {% do join_predicates.append(predicate) %}

            {% elif key_type == 'did' %}
                {# DID-based join #}
                {% set predicate = bian_alias ~ '.' ~ bian_col ~ ' = ' ~ crm_alias ~ '.did' %}
                {% do join_predicates.append(predicate) %}

            {% else %}
                {# Generic key: direct mapped attribute join #}
                {% set predicate = bian_alias ~ '.' ~ bian_col ~ ' = ' ~ crm_alias ~ '.' ~ crm_col %}
                {% do join_predicates.append(predicate) %}

            {% endif %}
        {% endif %}
    {% endfor %}

    {# Fallback: if no key predicates, raise error #}
    {% if join_predicates | length == 0 %}
        {% do exceptions.raise_compiler_error(
            'build_join_conditions: no key predicates found; check is_key in metadata'
        ) %}
    {% endif %}

    {# Join all predicates with AND #}
    {{ join_predicates | join(' AND ') }}
{% endmacro %}
```

**Usage example:**
```jinja
{% set on_clause = build_join_conditions(mappings, bian_alias='bian', crm_alias='crm') %}
```

---

## 7. Reconciliation Logic

The reconciliation engine is **fully metadata-driven**.  
No entity-specific SQL is written in the models.

### 7.1 dynamic_reconciliation() Macro

The `dynamic_reconciliation()` macro performs the following steps:

1. **Load metadata**  
   Load BIAN mapping metadata for the given domain and entity

2. **Identify key attributes**  
   Filter attributes where `is_key = 'Y'`

3. **Build join rules dynamically**
   - BIANSystem key attributes
   - CRM mapped key attributes
   - CRM reference logic:
     - `owner_id + owner_type_id` (composite keys)
     - `address_id` (direct join)
     - `did` (direct join)

4. **Load reconciliation type metadata**  
   Determine comparison rules for each attribute

5. **Build match_status**
   - `matched`
   - `mismatch`
   - `missing_in_source`
   - `missing_in_target`

6. **Build mismatch_columns array**  
   Contains attribute names only (no values)

7. **Build mismatch_count**  
   Count of attributes with mismatches

8. **Return SELECT block**  
   Contains only metadata fields:
   - domain
   - entity
   - primary keys (BIANSystem + CRM)
   - match_status
   - mismatch_columns
   - mismatch_count
   - reconciliation_type
   - run_id
   - load_timestamp

**No attribute values are included in the output.**

---

## 8. Mismatch Detection Logic

### 8.1 build_mismatch_array() Macro

Generates an array of attribute names where BIANSystem and CRM differ — **without exposing values**.

**File:** `macros/reconciliation/build_mismatch_array.sql`

```jinja
{% macro build_mismatch_array(mapping_rows, bian_alias='bian', crm_alias='crm') %}
    {# 
      Returns an array of attribute names that differ.
      No values are included.
    #}

    {% set mismatches = [] %}

    {% for row in mapping_rows %}
        {% set bian_col = row.bian_attribute %}
        {% set crm_col = row.crm_attribute %}

        {# Only compare non-key attributes #}
        {% if row.is_key | lower != 'y' %}
            {% set predicate %}
                case 
                    when {{ bian_alias }}.{{ bian_col }} is null 
                         and {{ crm_alias }}.{{ crm_col }} is null 
                        then null
                    when {{ bian_alias }}.{{ bian_col }} = {{ crm_alias }}.{{ crm_col }}
                        then null
                    else '{{ bian_col }}'
                end
            {% endset %}

            {% do mismatches.append(predicate) %}
        {% endif %}
    {% endfor %}

    array_remove(array_construct({{ mismatches | join(', ') }}), null)
{% endmacro %}
```

**Example output:**
```
['email_address', 'status_code']
```

### 8.2 build_mismatch_count() Macro

```jinja
{% macro build_mismatch_count(mismatch_array) %}
    array_length({{ mismatch_array }})
{% endmacro %}
```

### 8.3 build_match_status() Macro

Determines the final match status.

**File:** `macros/reconciliation/build_match_status.sql`

```jinja
{% macro build_match_status(bian_alias='bian', crm_alias='crm', mismatch_array='mismatch_cols') %}
    case
        when {{ bian_alias }}.primary_key is null 
             and {{ crm_alias }}.primary_key is not null
            then 'missing_in_source'

        when {{ bian_alias }}.primary_key is not null 
             and {{ crm_alias }}.primary_key is null
            then 'missing_in_target'

        when array_length({{ mismatch_array }}) > 0
            then 'mismatch'

        else 'matched'
    end
{% endmacro %}
```

**Match statuses:**
- `matched` - All attributes match
- `mismatch` - One or more attributes differ
- `missing_in_source` - Record exists in CRM but not BIANSystem
- `missing_in_target` - Record exists in BIANSystem but not CRM

### 8.4 Usage in dynamic_reconciliation()

```jinja
{% set mismatch_array = build_mismatch_array(mappings) %}
{% set mismatch_count = build_mismatch_count(mismatch_array) %}
{% set match_status = build_match_status(mismatch_array=mismatch_array) %}

select
    '{{ domain }}' as domain,
    '{{ entity }}' as entity,
    '{{ source_system }}' as source_system,
    '{{ target_system }}' as target_system,

    bian.primary_key as bian_primary_key,
    crm.primary_key as crm_primary_key,

    {{ match_status }} as match_status,
    {{ mismatch_array }} as mismatch_columns,
    {{ mismatch_count }} as mismatch_count,

    recon_type.reconciliation_type,
    {{ run_started_at }} as load_timestamp

from ...
```

This produces a metadata-only reconciliation record:
- No values
- No sensitive data
- Only mismatch metadata

---

## 9. Unified Mismatch Table

The model `recon_all_mismatches.sql` aggregates all reconciliation results across all domains and entities.

**File:** `models/reconciliation_summary/recon_all_mismatches.sql`

**Schema:**

| Column | Description |
|--------|-------------|
| `domain` | BIAN service domain |
| `entity` | BIAN business object |
| `source_system` | Always 'biansystem' |
| `target_system` | Always 'crm' |
| `bian_primary_key` | Primary key from BIANSystem |
| `crm_primary_key` | Primary key from CRM |
| `match_status` | matched, mismatch, missing_in_source, missing_in_target |
| `mismatch_columns` | Array of attribute names with differences |
| `mismatch_count` | Count of mismatched attributes |
| `reconciliation_type` | Type of reconciliation performed |
| `run_id` | Unique identifier for reconciliation run |
| `load_timestamp` | Timestamp of reconciliation execution |

**This table is used for:**
- Reporting dashboards
- Operational monitoring
- Audit trails
- Trend analysis

---

## 10. Value Investigation

Value-level investigation is performed **directly against staging models** on the day of analysis.

**No values are stored in reporting schemas.**

### Why This Approach?

- ✅ Staging models already contain clean, typed, transformed data
- ✅ No duplication of data
- ✅ No PII leakage into reporting schemas
- ✅ No need for a forensic schema
- ✅ No need to maintain extra tables

### How to Investigate Values

When a mismatch is identified:

1. Query the unified mismatch table to identify the record
2. Query staging models directly:
   ```sql
   -- BIANSystem value
   SELECT * FROM stg_biansystem_prdd_emails WHERE email_id = '12345';
   
   -- CRM value
   SELECT * FROM stg_crm_prdd_emails WHERE email_id = '12345';
   ```

---

## 11. Project Structure

The dbt project root is located in the **"crmdsl"** folder.

```
crmdsl/
├── dbt_project.yml
├── macros/
│   └── reconciliation/
│       ├── dynamic_reconciliation.sql
│       ├── build_join_conditions.sql
│       ├── build_match_status.sql
│       ├── build_mismatch_array.sql
│       ├── classify_crm_key_type.sql
│       └── transform_bian_mappings.sql
├── models/
│   ├── reconciliation/
│   │   └── <domain>/
│   │       ├── recon_<domain>_<entity>.sql
│   │       └── recon_<domain>_<entity>_exceptions.sql
│   └── reconciliation_summary/
│       ├── recon_all_mismatches.sql
│       └── bian_mappings_normalized.sql
├── seeds/
│   ├── bian_mappings.csv
│   └── bian_reconciliation_types.csv
└── staging/
    ├── stg_biansystem_<domain>_<entity>.sql
    └── stg_crm_<domain>_<entity>.sql
```

---

## 12. Reconciliation Model Template

Each reconciliation model is a **thin wrapper** that calls the macro.

**File:** `models/reconciliation/<domain>/recon_<domain>_<entity>.sql`

```sql
{{ config(
    materialized='table',
    schema='Reporting',
    alias='recon_{{ domain }}_{{ entity }}'
) }}

{{ dynamic_reconciliation(
    domain='prdd',
    entity='emails',
    source_system='biansystem',
    target_system='crm'
) }}
```

**No SQL is written in the model itself.**

---

## 13. Exception Models

Each entity may optionally define an exceptions model to capture:
- Known mismatches
- Business-approved overrides
- Tolerance rules

**File:** `models/reconciliation/<domain>/recon_<domain>_<entity>_exceptions.sql`

```sql
{{ config(
    materialized='table',
    schema='Reporting',
    alias='recon_{{ domain }}_{{ entity }}_exceptions'
) }}

-- Exception Model for {{ domain }}.{{ entity }}
-- Purpose:
--   Capture business-approved exceptions where mismatches should be ignored,
--   reclassified, or assigned a different match_status.

with base as (
    select * from {{ ref('recon_{{ domain }}_{{ entity }}') }}
),

exceptions as (
    -- EXAMPLE 1: Ignore mismatches for specific keys
    /*
    select
        domain,
        entity,
        source_system,
        target_system,
        bian_primary_key,
        crm_primary_key,
        'exception_ignored' as match_status,
        array_construct() as mismatch_columns,
        0 as mismatch_count,
        reconciliation_type,
        run_id,
        load_timestamp
    from base
    where bian_primary_key in ('12345', '67890')
    */

    -- EXAMPLE 2: Reclassify mismatches for tolerance rules
    /*
    select
        domain,
        entity,
        source_system,
        target_system,
        bian_primary_key,
        crm_primary_key,
        'tolerated_difference' as match_status,
        mismatch_columns,
        mismatch_count,
        reconciliation_type,
        run_id,
        load_timestamp
    from base
    where 'status_code' = any(mismatch_columns)
    */

    -- Default: no exceptions
    select * from base
)

select * from exceptions
```

**These models are stored alongside the reconciliation models.**

---

## 14. Running the Project

From the project root (`crmdsl` folder):

```bash
# Clean and refresh
dbt clean

# Load seed data
dbt seed

# Run all models
dbt run

# Run tests
dbt test
```

### Compile Only

```bash
dbt compile
```

### Run Specific Domain

```bash
dbt run --select recon_prdd_*
```

### Run Summary Model

```bash
dbt run --select recon_all_mismatches
```

---

## 15. Summary

This reconciliation framework is:

- ✅ **Metadata-driven** - All logic generated from seeds
- ✅ **Scalable** - Works across all BIAN domains
- ✅ **Consistent** - Same pattern for every entity
- ✅ **Auditable** - Complete lineage and documentation
- ✅ **Safe** - No values in reporting tables (metadata only)
- ✅ **Extensible** - Easy to add new domains/entities
- ✅ **Aligned with dbt best practices** - Modular macros, ref() usage, documented

### Key Principles

1. **No entity-specific SQL** - Everything is metadata-driven
2. **Metadata-only output** - Values investigated via staging models
3. **Dynamic join logic** - Handles complex CRM key types
4. **Unified mismatch table** - Single source of truth for reconciliation status
5. **Exception handling** - Business rules applied via exception models

The unified mismatch table provides a single source of truth for reconciliation status, while value investigation is performed directly against staging models.

---

## 16. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Metadata Seeds                           │
│  ┌─────────────────────┐  ┌──────────────────────────────┐ │
│  │ bian_mappings.csv   │  │ bian_reconciliation_types   │ │
│  └─────────────────────┘  └──────────────────────────────┘ │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │ Transformation Macro │
          │  transform_bian_     │
          │    _mappings()       │
          └──────────┬───────────┘
                     │
                     ▼
          ┌──────────────────────┐
          │ Normalized Metadata  │
          │ bian_mappings_       │
          │   normalized         │
          └──────────┬───────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌───────────────────┐    ┌───────────────────┐
│  BIANSystem       │    │  CRM              │
│  Staging Models   │    │  Staging Models   │
│  stg_biansystem_* │    │  stg_crm_*        │
└────────┬──────────┘    └────────┬──────────┘
         │                        │
         └────────┬───────────────┘
                  │
                  ▼
      ┌───────────────────────────┐
      │  dynamic_reconciliation() │
      │  ┌─────────────────────┐  │
      │  │ build_join_         │  │
      │  │   conditions()      │  │
      │  ├─────────────────────┤  │
      │  │ build_mismatch_     │  │
      │  │   array()           │  │
      │  ├─────────────────────┤  │
      │  │ build_match_        │  │
      │  │   status()          │  │
      │  └─────────────────────┘  │
      └────────────┬──────────────┘
                   │
                   ▼
        ┌──────────────────────────┐
        │ Reconciliation Models    │
        │ recon_<domain>_<entity>  │
        └────────────┬─────────────┘
                     │
                     ▼
        ┌──────────────────────────┐
        │ Unified Mismatch Table   │
        │ recon_all_mismatches     │
        └──────────────────────────┘
```

---

## 17. Next Steps

To implement this framework for a new domain/entity:

1. **Add metadata** to `bian_mappings.csv`
2. **Create staging models** for BIANSystem and CRM
3. **Create reconciliation model** using the template
4. **Run** `dbt seed && dbt run`
5. **Optional:** Create exception model if needed

No additional macro development required!

---

## 18. GitHub Copilot Implementation Prompt

You are assisting with implementing a metadata-driven reconciliation framework in dbt.
The goal is to generate a set of macros and model templates that reconcile BIANSystem staging entities against CRM staging entities using metadata from BIAN mapping seeds and BIAN reconciliation type seeds.

### IMPORTANT CONSTRAINTS

- The unified reconciliation output must NOT contain attribute values
- Only metadata should be produced: keys, mismatch columns, mismatch count, match status, reconciliation type, run_id, timestamps
- Value investigation will be performed directly against staging models, not stored in reporting schemas

### ARCHITECTURE TO IMPLEMENT

1. One reconciliation model per BIAN domain and entity
2. One unified mismatch table for all domains/entities
3. All join rules and comparison logic must be metadata-driven
4. No entity-specific SQL in models; everything must be generated by macros
5. No value-level columns in the reconciliation output

### SEED TABLES TO USE

**1. ref('bian_mappings')**

Columns include:
- domain
- entity
- bian_attribute
- crm_attribute
- is_key (Y/N)
- crm_key_type (owner, address, did, generic)

**2. ref('bian_reconciliation_types')**

Columns include:
- reconciliation_type
- join_type (left, full_outer)
- direction (one_way_left, both_ways)
- include_missing_source
- include_missing_target
- match_priority

### MACROS TO IMPLEMENT

**A. dynamic_reconciliation(domain, entity, source_system, target_system)**

Responsibilities:
- Load BIAN mappings for the domain/entity
- Identify key attributes (is_key = 'Y')
- Build dynamic join rules:
  - BIANSystem key attributes
  - CRM mapped key attributes
  - CRM reference logic:
    - owner_id + owner_type_id composite keys
    - address_id joins
    - did joins
- Load reconciliation type metadata
- Build match_status:
  - matched
  - mismatch
  - missing_in_source
  - missing_in_target
- Build mismatch_columns array (attribute names only)
- Build mismatch_count
- Return a SELECT block containing ONLY:
  - domain
  - entity
  - source_system
  - target_system
  - primary keys (BIANSystem + CRM)
  - match_status
  - mismatch_columns
  - mismatch_count
  - reconciliation_type
  - run_id
  - load_timestamp

**B. build_join_conditions(mapping_rows)**
- Accepts filtered BIAN mapping rows
- Generates the CRM join logic based on crm_key_type
- Must support composite keys and reference logic

**C. build_match_status()**
- Generates match_status using metadata and null checks

**D. build_mismatch_array()**
- Produces an array of attribute names that differ
- No values included

**E. build_mismatch_count()**
- Count of mismatched attributes

### MODEL TEMPLATES TO GENERATE

1. `models/reconciliation/<domain>/recon_<domain>_<entity>.sql`
   - Thin wrapper calling dynamic_reconciliation()

2. `models/reconciliation/<domain>/recon_<domain>_<entity>_exceptions.sql`
   - Optional override model for business exceptions

3. `models/reconciliation_summary/recon_all_mismatches.sql`
   - UNION ALL of all reconciliation models
   - Produces the unified mismatch table

### REQUIREMENTS

- Use ref() for staging models
- Use adapter.dispatch() for macro extensibility
- No hard-coded SQL for any entity
- No value-level columns in any reconciliation output
- Code must be clean, modular, and sponsor-grade

### DELIVERABLES

- All macros listed above
- All model templates
- Documentation blocks for each macro
- A working, metadata-driven reconciliation framework

Proceed to generate the full implementation.
