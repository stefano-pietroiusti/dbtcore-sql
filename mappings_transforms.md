Macro: classify_crm_key_type
--------------------------------
This macro inspects the CRM attribute name and assigns a key type used by the join builder.

Place in: macros/reconciliation/classify_crm_key_type.sql

{% macro classify_crm_key_type(column_name) %}
    case
        when lower({{ column_name }}) in ('owner_id', 'owner_type_id')
            then 'owner'
        when lower({{ column_name }}) = 'address_id'
            then 'address'
        when lower({{ column_name }}) = 'did'
            then 'did'
        else 'generic'
    end
{% endmacro %}

Macro: transform_bian_mappings
---------------------------------
This macro converts the raw seed into the normalized metadata format.

Place in: macros/reconciliation/transform_bian_mappings.sql

{% macro transform_bian_mappings() %}

    with raw as (
        select
              upper(bian_service_domain)      as domain
            , lower(sor_entity)               as entity
            , lower(sor_column)               as attribute
            , sor_system
            , is_key
            , is_active
        from {{ ref('bian_mappings') }}
        where is_active = 'Y'
    ),

    classified as (
        select
              domain
            , entity

            , case when sor_system = 'BIANSystem'
                   then attribute
              end as bian_attribute

            , case when sor_system = 'CRM'
                   then attribute
              end as crm_attribute

            , is_key

            , {{ classify_crm_key_type('attribute') }} as crm_key_type

        from raw
    ),

    aggregated as (
        select
              domain
            , entity

            , max(bian_attribute)  as bian_attribute
            , max(crm_attribute) as crm_attribute

            , max(is_key)         as is_key
            , max(crm_key_type)  as crm_key_type

        from classified
        group by domain, entity, attribute
    )

    select *
    from aggregated
    where bian_attribute is not null
      and crm_attribute is not null

{% endmacro %}

Creating the Normalized Metadata Model
-----------------------------------------
Create a model:

models/metadata/bian_mappings_normalized.sql

{{ transform_bian_mappings() }}

This produces the final metadata table used by:

- dynamic_reconciliation
- build_join_conditions
- build_mismatch_array
- build_match_status

