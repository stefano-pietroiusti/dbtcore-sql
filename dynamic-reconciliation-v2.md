# ======================================================================
# Dynamic BIAN Reconciliation — Simplified Architecture
# ======================================================================

## 1. Purpose
This document describes the simplified, metadata‑driven reconciliation
architecture used to compare DSL (flattened JSON) data with Onyx CRM data.

The architecture is designed to be:
- deterministic
- domain/entity‑agnostic
- fully metadata‑driven
- scalable across all BIAN domains
- sponsor‑grade and audit‑safe
- free of join rules, polymorphism, and entity‑specific SQL

The key principle:
**Both DSL and Onyx must be reshaped to the same BIAN domain/entity grain.**

Once the grain is aligned:
- Join rules disappear
- crm_key_type disappears
- mapping_rule disappears
- Polymorphic logic disappears
- Reconciliation becomes 100% metadata‑driven
- Macros become tiny
- Metadata becomes declarative

This README defines the metadata model, macros, source views, and output
structures that implement this architecture.

# ======================================================================
# 2. Metadata Model
# ======================================================================

The reconciliation engine requires only attribute mappings.

No join rules.
No key types.
No conditional logic.

### Metadata fields:
- domain
- entity
- dsl_attribute
- onyx_attribute
- is_key
- reconciliation_type
- is_active

### Example seed (bian_mappings.csv):

domain,entity,dsl_attribute,onyx_attribute,is_key,reconciliation_type,is_active
Party,Customer,partyReferenceId,partyReferenceId,Y,EXACT,Y
Party,Customer,fullName,full_name,N,NORMALIZED,Y
Party,Customer,email,email_address,N,NORMALIZED,Y
Party,Customer,phone,phone_number,N,EXACT,Y

Party,Address,partyReferenceId,partyReferenceId,Y,EXACT,Y
Party,Address,addressLine1,address_line_1,N,NORMALIZED,Y
Party,Address,postcode,postcode,N,EXACT,Y

Party,Email,partyReferenceId,partyReferenceId,Y,EXACT,Y
Party,Email,emailAddress,email_address,N,NORMALIZED,Y

Party,Phone,partyReferenceId,partyReferenceId,Y,EXACT,Y
Party,Phone,phoneNumber,phone_number,N,EXACT,Y

This metadata is the single source of truth for reconciliation.

# ======================================================================
# 3. Onyx Source Views (Reshaped to DSL Grain)
# ======================================================================

Onyx raw tables are reshaped into domain/entity‑specific staging views.

Each view:
- filters by type
- exposes partyReferenceId
- aligns with DSL grain
- eliminates polymorphism
- eliminates join rules

### Party.Customer
SELECT
    owner_id AS partyReferenceId,
    full_name,
    email_address,
    phone_number
FROM raw_onyx_owner
WHERE owner_type = 'Customer';

### Party.Address
SELECT
    address_id AS partyReferenceId,
    address_line_1,
    postcode
FROM raw_onyx_addresses
WHERE address_type = 'Physical';

### Party.RegisteredAddress
SELECT
    address_id AS partyReferenceId,
    address_line_1,
    postcode
FROM raw_onyx_addresses
WHERE address_type = 'Registered';

### Party.Email
SELECT
    email_party_id AS partyReferenceId,
    email_address
FROM raw_onyx_emails;

### Party.Phone
SELECT
    phone_party_id AS partyReferenceId,
    phone_number
FROM raw_onyx_phones;

These views ensure DSL and Onyx share the same grain.

# ======================================================================
# 4. Join Logic
# ======================================================================

All reconciliations use the same join:

{% macro build_join(domain, entity) %}
    ON dsl.partyReferenceId = onyx.partyReferenceId
{% endmacro %}

This eliminates:
- crm_key_type
- mapping_rule
- polymorphic join logic
- entity‑specific join rules

# ======================================================================
# 5. Comparison Logic
# ======================================================================

Comparison is driven entirely by reconciliation_type:

- EXACT
- NORMALIZED
- DATE_ONLY

Example macro:

{% macro build_comparison_expression(dsl_col, onyx_col, reconciliation_type) %}
    {% if reconciliation_type == 'EXACT' %}
        {{ dsl_col }} = {{ onyx_col }}
    {% elif reconciliation_type == 'NORMALIZED' %}
        lower(trim({{ dsl_col }})) = lower(trim({{ onyx_col }}))
    {% elif reconciliation_type == 'DATE_ONLY' %}
        date({{ dsl_col }}) = date({{ onyx_col }})
    {% else %}
        {{ dsl_col }} = {{ onyx_col }}
    {% endif %}
{% endmacro %}

# ======================================================================
# 6. Dynamic Reconciliation Macro
# ======================================================================

{% macro dynamic_reconciliation(domain, entity) %}

WITH meta AS (
    SELECT *
    FROM {{ ref('bian_mappings_normalized') }}
    WHERE domain = '{{ domain }}'
      AND entity = '{{ entity }}'
      AND is_active = 'Y'
),

joined AS (
    SELECT
        dsl.*,
        onyx.*,
        {{ dbt_utils.generate_surrogate_key(
            meta | where("is_key = 'Y'") | map(attribute='dsl_attribute')
        ) }} AS pk_hash
    FROM {{ ref('stg_dsl_' ~ domain ~ '_' ~ entity) }} AS dsl
    LEFT JOIN {{ ref('stg_onyx_' ~ domain ~ '_' ~ entity) }} AS onyx
        {{ build_join(domain, entity) }}
),

compare AS (
    SELECT
        '{{ domain }}' AS domain,
        '{{ entity }}' AS entity,
        pk_hash,
        m.dsl_attribute AS attribute_name,
        m.reconciliation_type,
        CASE
            WHEN {{ build_comparison_expression(
                    'dsl.' ~ m.dsl_attribute,
                    'onyx.' ~ m.onyx_attribute,
                    m.reconciliation_type
                 ) }}
            THEN 'MATCH'
            ELSE 'MISMATCH'
        END AS match_status,
        CASE
            WHEN {{ build_comparison_expression(
                    'dsl.' ~ m.dsl_attribute,
                    'onyx.' ~ m.onyx_attribute,
                    m.reconciliation_type
                 ) }}
            THEN NULL
            ELSE 'Comparison failed: ' || m.reconciliation_type
        END AS mismatch_reason
    FROM joined
    CROSS JOIN meta AS m
)

SELECT * FROM compare;

{% endmacro %}

This macro is:
- deterministic
- tiny
- metadata‑only
- domain/entity‑agnostic

# ======================================================================
# 7. Reconciliation Output (Unified Table)
# ======================================================================

The engine produces a metadata‑only mismatch ledger:

- domain
- entity
- primary_key_hash
- attribute_name
- reconciliation_type
- match_status
- mismatch_reason
- run_timestamp

No values are stored.

This table is safe for:
- dashboards
- audit
- monitoring
- sponsor reporting

# ======================================================================
# 8. Operational Characteristics
# ======================================================================

### Deterministic
No conditional logic. No polymorphism. No entity‑specific SQL.

### Scalable
New domains/entities require only:
- a DSL table
- an Onyx view
- metadata rows

### Audit‑Safe
No values stored in reconciliation output.

### Sponsor‑Grade
Architecture is simple, declarative, and fully metadata‑driven.

# ======================================================================
# 9. Summary
# ======================================================================

By aligning Onyx to the DSL grain, the reconciliation engine becomes:

- deterministic
- metadata‑driven
- domain‑agnostic
- scalable
- sponsor‑grade
- easy to maintain
- easy to extend

No join rules.
No polymorphism.
No complexity.

This is the canonical, simplified architecture for BIAN reconciliation.

# ======================================================================
# END OF README
# ======================================================================
