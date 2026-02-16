Dynamic Reconciliation Framework

1. Overview This project implements a metadata‑driven reconciliation engine between DSL staging entities and ONYX staging entities. The engine uses BIAN mapping metadata and BIAN reconciliation type metadata to dynamically generate reconciliation logic, join rules, and mismatch detection without hard‑coding any entity‑specific SQL.


The reconciliation layer produces:

• A unified mismatch table containing only metadata (no attribute values)
• Optional forensic tables for value‑level investigation
• One reconciliation model per BIAN domain and entity
• A macro framework that dynamically builds join rules, comparison logic, and match status


This design ensures scalability, auditability, and consistency across all BIAN domains and entities.

---

1. Project Structure The dbt project root is located in the “crmdsl” folder.
The folder structure is:


crmdsl/ dbt_project.yml macros/ reconciliation/ dynamic_reconciliation.sql build_join_conditions.sql build_match_status.sql build_mismatch_array.sql dynamic_value_diff.sql (optional forensic macro) models/ reconciliation/ / recon_.sql reconexceptions.sql reconciliation_summary/ recon_all_mismatches.sql reconciliation_forensics/ reconvalue_diffs.sql (optional) seeds/ bian_mappings.csv bian_reconciliation_types.csv staging/ staging.sql

---

1. Metadata Inputs The reconciliation engine relies on two seed tables:
2. bian_mappings• Defines how DSL attributes map to ONYX attributes
• Identifies key attributes using is_key = ‘Y’
• Provides onyx_key_type to support reference logic: owner address did generic

3. bian_reconciliation_types• Defines reconciliation behavior: join_type (left, full_outer) direction (one_way_left, both_ways) include_missing_source include_missing_target match_priority



---

1. Reconciliation Logic The reconciliation engine is fully metadata‑driven.
No entity‑specific SQL is written in the models.


The dynamic_reconciliation() macro performs the following steps:

1. Load BIAN mapping metadata for the given domain and entity.
2. Identify key attributes (is_key = ‘Y’).
3. Build join rules dynamically:• DSL key attributes
• ONYX mapped key attributes
• ONYX reference logic: owner_id + owner_type_id address_id did

4. Load reconciliation type metadata.
5. Build match_status: matched mismatch missing_in_source missing_in_target
6. Build mismatch_columns array (attribute names only).
7. Build mismatch_count.
8. Return a SELECT block containing only metadata fields: domain entity primary keys match_status mismatch_columns mismatch_count reconciliation_type run_id load_timestamp


No attribute values are included in the output.

---

1. Unified Mismatch Table The model recon_all_mismatches.sql aggregates all reconciliation results across all domains and entities.


This table contains:

• domain
• entity
• source_system
• target_system
• primary keys
• match_status
• mismatch_columns
• mismatch_count
• reconciliation_type
• run_id
• load_timestamp


This table is used for reporting, dashboards, and operational monitoring.

---

1. Forensic Value‑Level Investigation (Optional) A separate schema is used for value‑level investigation.


The dynamic_value_diff() macro produces:

• DSL value
• ONYX value
• attribute_name
• mismatch_reason
• primary keys


These tables are stored under reconciliation_forensics/ and are not used for reporting.

---

1. Reconciliation Model Template Each reconciliation model is a thin wrapper that calls the macro:


{{ dynamic_reconciliation( domain = ‘prdd’, entity = ‘emails’, source_system = ‘dsl’, target_system = ‘onyx’ ) }}

No SQL is written in the model itself.

---

1. Exception Models Each entity may optionally define an exceptions model to capture:


• known mismatches
• business‑approved overrides
• tolerance rules


These models are stored alongside the reconciliation models.

---

1. Running the Project From the project root (crmdsl folder):


dbt clean dbt seed dbt run dbt test

To compile only:

dbt compile

---

1. Summary This reconciliation framework is:


• metadata‑driven
• scalable across all BIAN domains
• consistent and auditable
• safe (no values in reporting tables)
• extensible via macros
• aligned with dbt best practices




1. The unified mismatch table becomes purely metadata

It contains:

• domain
• entity
• source_system
• target_system
• primary keys (DSL + ONYX)
• match_status
• mismatch_columns (array of column names only)
• mismatch_count
• reconciliation_type
• run_id
• load_timestamp


No values.
No diffs.
No before/after.

2. Value investigation happens by querying staging models directly

This is actually ideal because:

• staging models already contain clean, typed, transformed data
• no duplication
• no PII leakage into reporting schemas
• no need for a forensic schema
• no need to maintain extra tables


3. The reconciliation macro becomes simpler

It only needs to:

• build join rules
• detect mismatches
• produce metadata
• not produce value-level columns


4. The reconciliation models remain thin wrappers

Each entity model calls:

{{ dynamic_reconciliation(domain='prdd', entity='emails', source_system='dsl', target_system='onyx') }}


5. The summary model aggregates everything

One table for all mismatches across all domains and entities.

---

⭐ Updated README.txt (copy/paste ready)

Below is the revised README.txt reflecting the “no forensic layer” design.

---

README.txt
Dynamic Reconciliation Framework (Metadata‑Only)

1. Overview This project implements a metadata‑driven reconciliation engine between DSL staging entities and ONYX staging entities. The engine uses BIAN mapping metadata and BIAN reconciliation type metadata to dynamically generate reconciliation logic, join rules, and mismatch detection without hard‑coding any entity‑specific SQL.


The reconciliation layer produces:

• A unified mismatch table containing only metadata (no attribute values)
• One reconciliation model per BIAN domain and entity
• A macro framework that dynamically builds join rules, comparison logic, and match status


Actual value investigation is performed directly against staging models and is not stored in reporting schemas.

---

1. Project Structure


crmdsl/ dbt_project.yml macros/ reconciliation/ dynamic_reconciliation.sql build_join_conditions.sql build_match_status.sql build_mismatch_array.sql models/ reconciliation/ / recon_.sql reconexceptions.sql reconciliation_summary/ recon_all_mismatches.sql seeds/ bian_mappings.csv bian_reconciliation_types.csv staging/ staging_.sql

---

1. Metadata Inputs
2. bian_mappings• Defines how DSL attributes map to ONYX attributes
• Identifies key attributes using is_key = ‘Y’
• Provides onyx_key_type to support reference logic: owner address did generic

3. bian_reconciliation_types• Defines reconciliation behavior: join_type (left, full_outer) direction (one_way_left, both_ways) include_missing_source include_missing_target match_priority



---

1. Reconciliation Logic


The dynamic_reconciliation() macro performs the following steps:

1. Load BIAN mapping metadata for the given domain and entity.
2. Identify key attributes (is_key = ‘Y’).
3. Build join rules dynamically:• DSL key attributes
• ONYX mapped key attributes
• ONYX reference logic: owner_id + owner_type_id address_id did

4. Load reconciliation type metadata.
5. Build match_status: matched mismatch missing_in_source missing_in_target
6. Build mismatch_columns array (attribute names only).
7. Build mismatch_count.
8. Return a SELECT block containing only metadata fields: domain entity primary keys match_status mismatch_columns mismatch_count reconciliation_type run_id load_timestamp


No attribute values are included in the output.

---

1. Unified Mismatch Table


The model recon_all_mismatches.sql aggregates all reconciliation results across all domains and entities.

This table contains:

• domain
• entity
• source_system
• target_system
• primary keys
• match_status
• mismatch_columns
• mismatch_count
• reconciliation_type
• run_id
• load_timestamp


This table is used for reporting, dashboards, and operational monitoring.

---

1. Value Investigation


Value‑level investigation is performed directly against staging models on the day of analysis.

No values are stored in reporting schemas.

---

1. Reconciliation Model Template


Each reconciliation model is a thin wrapper that calls the macro:

{{ dynamic_reconciliation( domain = ‘prdd’, entity = ‘emails’, source_system = ‘dsl’, target_system = ‘onyx’ ) }}

No SQL is written in the model itself.

---

1. Exception Models


Each entity may optionally define an exceptions model to capture:

• known mismatches
• business‑approved overrides
• tolerance rules


These models are stored alongside the reconciliation models.

---

1. Running the Project


From the project root (crmdsl folder):

dbt clean
dbt seed
dbt run
dbt test

To compile only:

dbt compile

---

1. Summary


This reconciliation framework is:

• metadata‑driven
• scalable across all BIAN domains
• consistent and auditable
• safe (no values in reporting tables)
• extensible via macros
• aligned with dbt best practices


The unified mismatch table provides a single source of truth for reconciliation status, while value investigation is performed directly against staging.

Absolutely, Stefano — here is the clean, final, copy‑and‑paste‑ready GitHub Copilot prompt that will instruct Copilot to generate the entire reconciliation framework exactly the way you want it.

This version is tuned for Copilot’s agent mode: explicit, directive, and schema‑driven.

No forensic layer.
No value‑level output.
Metadata‑only reconciliation.
Dynamic join rules.
Dynamic mismatch detection.
Fully metadata‑driven.

---

GITHUB COPILOT IMPLEMENTATION PROMPT (TXT)

You are assisting with implementing a metadata‑driven reconciliation framework in dbt.
The goal is to generate a set of macros and model templates that reconcile DSL staging entities against ONYX staging entities using metadata from BIAN mapping seeds and BIAN reconciliation type seeds.

IMPORTANT CONSTRAINTS:

• The unified reconciliation output must NOT contain attribute values.
• Only metadata should be produced: keys, mismatch columns, mismatch count, match status, reconciliation type, run_id, timestamps.
• Value investigation will be performed directly against staging models, not stored in reporting schemas.


ARCHITECTURE TO IMPLEMENT:

1. One reconciliation model per BIAN domain and entity.
2. One unified mismatch table for all domains/entities.
3. All join rules and comparison logic must be metadata‑driven.
4. No entity‑specific SQL in models; everything must be generated by macros.
5. No value‑level columns in the reconciliation output.


SEED TABLES TO USE:

1. ref(‘bian_mappings’) Columns include:• domain
• entity
• dsl_attribute
• onyx_attribute
• is_key (Y/N)
• onyx_key_type (owner, address, did, generic)

2. ref(‘bian_reconciliation_types’) Columns include:• reconciliation_type
• join_type (left, full_outer)
• direction (one_way_left, both_ways)
• include_missing_source
• include_missing_target
• match_priority



MACROS TO IMPLEMENT:

A. dynamic_reconciliation(domain, entity, source_system, target_system) Responsibilities:

• Load BIAN mappings for the domain/entity.
• Identify key attributes (is_key = ‘Y’).
• Build dynamic join rules:• DSL key attributes
• ONYX mapped key attributes
• ONYX reference logic:• owner_id + owner_type_id composite keys
• address_id joins
• did joins


• Load reconciliation type metadata.
• Build match_status:• matched
• mismatch
• missing_in_source
• missing_in_target

• Build mismatch_columns array (attribute names only).
• Build mismatch_count.
• Return a SELECT block containing ONLY: domain entity source_system target_system primary keys (DSL + ONYX) match_status mismatch_columns mismatch_count reconciliation_type run_id load_timestamp


B. build_join_conditions(mapping_rows)

• Accepts filtered BIAN mapping rows.
• Generates the ONYX join logic based on onyx_key_type.
• Must support composite keys and reference logic.


C. build_match_status()

• Generates match_status using metadata and null checks.


D. build_mismatch_array()

• Produces an array of attribute names that differ.
• No values included.


E. build_mismatch_count()

• Count of mismatched attributes.


MODEL TEMPLATES TO GENERATE:

1. models/reconciliation//recon__.sql• Thin wrapper calling dynamic_reconciliation().

2. models/reconciliation//recon___exceptions.sql• Optional override model for business exceptions.

3. models/reconciliation_summary/recon_all_mismatches.sql• UNION ALL of all reconciliation models.
• Produces the unified mismatch table.



REQUIREMENTS:

• Use ref() for staging models.
• Use adapter.dispatch() for macro extensibility.
• No hard‑coded SQL for any entity.
• No value‑level columns in any reconciliation output.
• Code must be clean, modular, and sponsor‑grade.


DELIVERABLES:

• All macros listed above.
• All model templates.
• Documentation blocks for each macro.
• A working, metadata‑driven reconciliation framework.


Proceed to generate the full implementation.

---
• the macro skeletons


• the join‑rule builder logic

Here’s a sponsor‑grade join rule builder you can drop straight into macros/reconciliation/build_join_conditions.sql.

It assumes:

• mapping_rows is a list of rows from ref('bian_mappings') filtered to the current domain + entity.
• Each row has: dsl_attribute, onyx_attribute, is_key, onyx_key_type.
• You call this from dynamic_reconciliation() to get a single ON clause string.


{% macro build_join_conditions(mapping_rows, dsl_alias='dsl', onyx_alias='onyx') %}
    {# 
      mapping_rows: list of mapping records for a given domain/entity
      Each row should expose:
        - dsl_attribute
        - onyx_attribute
        - is_key
        - onyx_key_type (owner, address, did, generic)
    #}

    {# Collect individual join predicates here #}
    {% set join_predicates = [] %}

    {% for row in mapping_rows %}
        {% if row.is_key is string and row.is_key | lower == 'y' %}

            {% set dsl_col = row.dsl_attribute %}
            {% set onyx_col = row.onyx_attribute %}
            {% set key_type = (row.onyx_key_type or 'generic') | lower %}

            {# 
              Handle special ONYX key types.
              We assume the staging models already expose the right columns:
                - owner_id, owner_type_id
                - address_id
                - did
              The mapping metadata tells us how to interpret the DSL side.
            #}

            {% if key_type == 'owner' %}
                {# 
                  Owner-based join:
                  onyx.owner_id + onyx.owner_type_id identify the ONYX record.
                  The DSL side may expose a single logical key that maps to both.
                  Here we assume:
                    - dsl.<dsl_col> maps to onyx.owner_id
                    - and we have a separate mapping row for owner_type_id if needed.
                  If your metadata encodes both, you can refine this.
                #}
                {% set predicate = dsl_alias ~ '.' ~ dsl_col ~ ' = ' ~ onyx_alias ~ '.owner_id' %}
                {% do join_predicates.append(predicate) %}

            {% elif key_type == 'address' %}
                {# Address-based join: onyx.address_id = dsl.<dsl_col> #}
                {% set predicate = dsl_alias ~ '.' ~ dsl_col ~ ' = ' ~ onyx_alias ~ '.address_id' %}
                {% do join_predicates.append(predicate) %}

            {% elif key_type == 'did' %}
                {# DID-based join: onyx.did = dsl.<dsl_col> #}
                {% set predicate = dsl_alias ~ '.' ~ dsl_col ~ ' = ' ~ onyx_alias ~ '.did' %}
                {% do join_predicates.append(predicate) %}

            {% else %}
                {# Generic key: direct mapped attribute join #}
                {% set predicate = dsl_alias ~ '.' ~ dsl_col ~ ' = ' ~ onyx_alias ~ '.' ~ onyx_col %}
                {% do join_predicates.append(predicate) %}

            {% endif %}
        {% endif %}
    {% endfor %}

    {# Fallback: if no key predicates, raise a compiler error #}
    {% if join_predicates | length == 0 %}
        {% do exceptions.raise_compiler_error(
            'build_join_conditions: no key predicates found for mapping_rows; check is_key and metadata.'
        ) %}
    {% endif %}

    {# Join all predicates with AND to form the ON clause #}
    {{ join_predicates | join(' AND ') }}
{% endmacro %}


And here’s a typical way you’d call it inside dynamic_reconciliation():

{% macro dynamic_reconciliation(domain, entity, source_system, target_system) %}
    {% set mappings = (
        ref('bian_mappings')
        | where("domain", "=", domain)
        | where("entity", "=", entity)
    ) %}

    {% set on_clause = build_join_conditions(mappings, dsl_alias='dsl', onyx_alias='onyx') %}

    select
        -- metadata-only select here
    from {{ ref('staging_' ~ source_system ~ '_' ~ domain ~ '_' ~ entity) }} as dsl
    join {{ ref('staging_' ~ target_system ~ '_' ~ domain ~ '_' ~ entity) }} as onyx
        on {{ on_clause }}
{% endmacro %}


If metadata encodes owner_id and owner_type_id as separate rows,  extend this to group by onyx_key_type and build composite predicates—happy to tighten that next if you want composite owner logic fully explicit.


• the mismatch detection logic

This is the piece that sits inside macros/reconciliation/build_match_status.sql and build_mismatch_array.sql.
It plugs directly into your dynamic reconciliation macro.

I’ll give you:

1. mismatch array builder
2. mismatch count builder
3. match status builder
4. A usage example inside a SELECT


Everything is metadata‑driven and safe for reporting.

---

MISMATCH ARRAY BUILDER

This macro receives the mapping rows and generates an array of attribute names where DSL and ONYX differ — without exposing values.

{% macro build_mismatch_array(mapping_rows, dsl_alias='dsl', onyx_alias='onyx') %}
    {# 
      Returns an array of attribute names that differ.
      No values are included.
    #}

    {% set mismatches = [] %}

    {% for row in mapping_rows %}
        {% set dsl_col = row.dsl_attribute %}
        {% set onyx_col = row.onyx_attribute %}

        {# Only compare non-key attributes #}
        {% if row.is_key | lower != 'y' %}
            {% set predicate %}
                case 
                    when {{ dsl_alias }}.{{ dsl_col }} is null 
                         and {{ onyx_alias }}.{{ onyx_col }} is null 
                        then null
                    when {{ dsl_alias }}.{{ dsl_col }} = {{ onyx_alias }}.{{ onyx_col }}
                        then null
                    else '{{ dsl_col }}'
                end
            {% endset %}

            {% do mismatches.append(predicate) %}
        {% endif %}
    {% endfor %}

    array_remove(array_construct({{ mismatches | join(', ') }}), null)
{% endmacro %}


This produces an array like:

['email_address', 'status_code']

But never the values.

---

MISMATCH COUNT BUILDER

{% macro build_mismatch_count(mismatch_array) %}
    array_length({{ mismatch_array }})
{% endmacro %}

Simple, clean, and warehouse‑agnostic.

---

MATCH STATUS BUILDER

This macro determines the final match status using:

• missing in source
• missing in target
• mismatch array length

{% macro build_match_status(dsl_alias='dsl', onyx_alias='onyx', mismatch_array='mismatch_cols') %}
    case
        when {{ dsl_alias }}.primary_key is null 
             and {{ onyx_alias }}.primary_key is not null
            then 'missing_in_source'

        when {{ dsl_alias }}.primary_key is not null 
             and {{ onyx_alias }}.primary_key is null
            then 'missing_in_target'

        when array_length({{ mismatch_array }}) > 0
            then 'mismatch'

        else 'matched'
    end
{% endmacro %}

You can adjust the primary key reference depending on how you expose it (flattened or JSON).

---

HOW THESE MACROS ARE USED IN THE RECONCILIATION SELECT

Inside dynamic_reconciliation():

{% set mismatch_array = build_mismatch_array(mappings) %}
{% set mismatch_count = build_mismatch_count(mismatch_array) %}
{% set match_status = build_match_status(mismatch_array=mismatch_array) %}

select
    '{{ domain }}' as domain,
    '{{ entity }}' as entity,
    '{{ source_system }}' as source_system,
    '{{ target_system }}' as target_system,

    dsl.primary_key as dsl_primary_key,
    onyx.primary_key as onyx_primary_key,

    {{ match_status }} as match_status,
    {{ mismatch_array }} as mismatch_columns,
    {{ mismatch_count }} as mismatch_count,

    recon_type.reconciliation_type,
    {{ run_started_at() }} as load_timestamp

from ...

This produces a metadata‑only reconciliation record:

• No values
• No sensitive data
• Only mismatch metadata


Exactly what you need for your reporting schema.

---


• the full dynamic_reconciliation macro
• the summary model
• the exception model template

models/reconciliation/<domain>/recon_<domain>_<entity>_exceptions.sql

EXCEPTION MODEL TEMPLATE (TXT)

{{ config( materialized = ‘table’, schema = ‘Reporting’, alias = ‘recon___exceptions’ ) }}

– Exception Model for <domain>.<entity> – Purpose: –   Capture business‑approved exceptions where mismatches should be ignored, –   reclassified, or assigned a different match_status.

– Notes: –   1. This model NEVER contains value‑level data. –   2. This model ONLY references the unified mismatch metadata. –   3. All exceptions must be explicit and documented. –   4. The main reconciliation model remains untouched.

with base as ( select * from {{ ref(‘recon__’) }} ),

exceptions as (

-- EXAMPLE 1: Ignore mismatches for specific keys
-- Uncomment and adjust as needed
/*
select
    domain,
    entity,
    source_system,
    target_system,
    dsl_primary_key,
    onyx_primary_key,
    'exception_ignored' as match_status,
    array_construct() as mismatch_columns,
    0 as mismatch_count,
    reconciliation_type,
    run_id,
    load_timestamp
from base
where dsl_primary_key in ('12345', '67890')
*/

-- EXAMPLE 2: Reclassify mismatches for known tolerance rules
/*
select
    domain,
    entity,
    source_system,
    target_system,
    dsl_primary_key,
    onyx_primary_key,
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
select *
from base


)

select * from exceptions;

---

HOW THIS TEMPLATE WORKS

1. It starts by selecting from the main reconciliation model: recon__
2. It allows you to:• ignore mismatches

• reclassify mismatches
• apply tolerance rules
• override match_status

3. It never exposes values — only metadata.
4. It returns the same schema as the main reconciliation model, so the summary model can UNION ALL safely.


---

• the BIAN mapping validator
• the ONYX reference join logic (owner/address/did composite handling)


Just tell me which piece you want next.

• the summary model

• the seed schema

• the folder structure scaffolding


Just tell me what you want next.