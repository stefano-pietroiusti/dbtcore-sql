# Macros in dbt

Macros are functions written in Jinja that allow you to write generic logic once and then reference it throughout your project.

## Why Use Macros?

Consider the case where you have three models that use the same logic. You could copy-paste the logic between those three models, but if you want to change that logic, you need to make the change in three different places.

**Macros solve this problem** by allowing you to:
- ✅ Write logic once in one place
- ✅ Reference that logic in multiple models
- ✅ Make changes in one location that automatically propagate everywhere

---

## DRY Code

Macros allow us to write **DRY (Don't Repeat Yourself)** code in our dbt project. This enables you to take a model file that was 200 lines of code and compress it down to 50 lines by abstracting logic into macros.

### The Tradeoff

⚠️ **Important:** Balance readability/maintainability with conciseness.

As you work through your dbt project, remember:
- You are not the only one using this code
- Be mindful and intentional about where you use macros
- Sometimes explicit code is better than overly abstracted macros
- Consider your team's skill level and familiarity with macros

---

## Example: Cents to Dollars

### Original Model

```sql
select
    id as payment_id,
    orderid as order_id,
    paymentmethod as payment_method,
    status,
    -- amount stored in cents, convert to dollars
    amount / 100 as amount,
    created as created_at
from {{ source('stripe', 'payment') }}
```

### Create the Macro

**File:** `macros/cents_to_dollars.sql`

```jinja
{% macro cents_to_dollars(column_name, decimal_places=2) -%}
round( 1.0 * {{ column_name }} / 100, {{ decimal_places }})
{%- endmacro %}
```

### Refactored Model

```sql
select
    id as payment_id,
    orderid as order_id,
    paymentmethod as payment_method,
    status,
    -- amount stored in cents, convert to dollars
    {{ cents_to_dollars('amount') }} as amount,
    created as created_at
from {{ source('stripe', 'payment') }}
```

**Benefits:**
- ✅ Reusable across multiple models
- ✅ Easy to change decimal precision
- ✅ Consistent conversion logic
- ✅ Self-documenting code

---

## Macros Cheat Sheet

### Basic Macro Syntax

```jinja
{# Define a macro #}
{% macro macro_name(arg1, arg2='default_value') %}
    -- Your SQL or Jinja logic here
    {{ arg1 }} + {{ arg2 }}
{% endmacro %}

{# Call a macro #}
{{ macro_name('value1', 'value2') }}
{{ macro_name('value1') }}  -- Uses default for arg2
```

### Macro File Organization

```
macros/
├── get_column_values.sql
├── generate_schema_name.sql
├── cents_to_dollars.sql
└── custom_tests/
    ├── test_valid_status.sql
    └── test_date_range.sql
```

**Rules:**
- Place macros in the `macros/` directory
- One macro per file (recommended) or group related macros
- Macros are globally available (no imports needed)
- Can organize into subdirectories

---

### Common Macro Patterns

#### 1. Value Transformation

```jinja
{% macro standardize_phone(phone_column) %}
    regexp_replace({{ phone_column }}, '[^0-9]', '')
{% endmacro %}
```

**Usage:**
```sql
select
    {{ standardize_phone('phone_number') }} as clean_phone
from customers
```

#### 2. Conditional SQL Generation

```jinja
{% macro generate_alias(custom_alias_name=none, node=none) %}
    {% if custom_alias_name %}
        {{ custom_alias_name }}
    {% else %}
        {{ node.name }}
    {% endif %}
{% endmacro %}
```

#### 3. Column List Generation

```jinja
{% macro get_column_list(table_name, exclude_columns=[]) %}
    {% set columns = adapter.get_columns_in_relation(ref(table_name)) %}
    {% for col in columns if col.name not in exclude_columns %}
        {{ col.name }}{{ ',' if not loop.last }}
    {% endfor %}
{% endmacro %}
```

**Usage:**
```sql
select
    {{ get_column_list('stg_orders', ['internal_notes']) }}
from {{ ref('stg_orders') }}
```

#### 4. Surrogate Key Generation

```jinja
{% macro generate_surrogate_key(field_list) %}
    md5({% for field in field_list %}
        coalesce(cast({{ field }} as varchar), '')
        {{ " || '|' || " if not loop.last }}
    {% endfor %})
{% endmacro %}
```

**Usage:**
```sql
select
    {{ generate_surrogate_key(['customer_id', 'order_id']) }} as unique_key
from orders
```

#### 5. Pivot Table Generation

```jinja
{% macro pivot_values(column, values, agg_function='sum', suffix='', default_value=0) %}
    {% for value in values %}
        {{ agg_function }}(
            case when {{ column }} = '{{ value }}' 
            then 1 else {{ default_value }} end
        ) as {{ value }}{{ suffix }}
        {{- ',' if not loop.last }}
    {% endfor %}
{% endmacro %}
```

**Usage:**
```sql
select
    customer_id,
    {{ pivot_values('product_category', ['electronics', 'clothing', 'food'], agg_function='count', suffix='_purchases') }}
from orders
group by customer_id
```

#### 6. Date Spine Generation

```jinja
{% macro generate_date_spine(start_date, end_date) %}
    with date_spine as (
        {% for i in range((end_date - start_date).days + 1) %}
            select 
                '{{ start_date }}' + interval '{{ i }} days' as date_day
            {{ 'union all' if not loop.last }}
        {% endfor %}
    )
    select * from date_spine
{% endmacro %}
```

#### 7. Union Tables

```jinja
{% macro union_tables(tables, column_override={}) %}
    {% for table in tables %}
        select
            '{{ table }}' as source_table,
            *
            {% for col, val in column_override.items() %}
            , {{ val }} as {{ col }}
            {% endfor %}
        from {{ ref(table) }}
        {{ 'union all' if not loop.last }}
    {% endfor %}
{% endmacro %}
```

**Usage:**
```sql
{{ union_tables(['orders_2023', 'orders_2024', 'orders_2025']) }}
```

---

### dbt-Specific Macro Features

#### Access Adapter Methods

```jinja
{% macro get_table_columns(schema_name, table_name) %}
    {% set relation = adapter.get_relation(
        database=target.database,
        schema=schema_name,
        identifier=table_name
    ) %}
    
    {% if relation %}
        {% set columns = adapter.get_columns_in_relation(relation) %}
        {% for col in columns %}
            {{ col.name }} ({{ col.dtype }}){{ ',' if not loop.last }}
        {% endfor %}
    {% endif %}
{% endmacro %}
```

#### Execute Queries in Macros

```jinja
{% macro get_distinct_values(table, column) %}
    {% set query %}
        select distinct {{ column }}
        from {{ ref(table) }}
        order by {{ column }}
    {% endset %}
    
    {% set results = run_query(query) %}
    
    {% if execute %}
        {% set values = results.columns[0].values() %}
        {{ return(values) }}
    {% else %}
        {{ return([]) }}
    {% endif %}
{% endmacro %}
```

**Usage:**
```jinja
{% set payment_methods = get_distinct_values('stg_payments', 'payment_method') %}

{% for method in payment_methods %}
    sum(case when payment_method = '{{ method }}' then amount end) as {{ method }}_amount
    {{- ',' if not loop.last }}
{% endfor %}
```

---

### Custom Generic Tests

Generic tests are reusable tests written as macros.

**File:** `macros/tests/test_valid_status.sql`

```jinja
{% test valid_status(model, column_name, valid_statuses) %}

select *
from {{ model }}
where {{ column_name }} not in (
    {% for status in valid_statuses %}
        '{{ status }}'{{ ',' if not loop.last }}
    {% endfor %}
)

{% endtest %}
```

**Usage in schema.yml:**
```yaml
models:
  - name: orders
    columns:
      - name: status
        tests:
          - valid_status:
              valid_statuses: ['pending', 'completed', 'cancelled']
```

---

### Macro with Documentation

```jinja
{% macro log_event(message, level='info') %}
    {%- set levels = {
        'debug': 'DEBUG',
        'info': 'INFO',
        'warn': 'WARN',
        'error': 'ERROR'
    } -%}
    
    {# 
        Log an event with a specific level
        
        Args:
            message (str): The message to log
            level (str): Log level - debug, info, warn, error
            
        Returns:
            None (logs to console)
    #}
    
    {{ log("[" ~ levels.get(level, 'INFO') ~ "] " ~ message, info=True) }}
{% endmacro %}
```

---

### Accessing Target Context

```jinja
{% macro get_warehouse_size() %}
    {% if target.name == 'prod' %}
        {{ return('XLARGE') }}
    {% elif target.name == 'dev' %}
        {{ return('SMALL') }}
    {% else %}
        {{ return('MEDIUM') }}
    {% endif %}
{% endmacro %}
```

**Usage:**
```sql
{{ config(
    materialized='table',
    warehouse_size=get_warehouse_size()
) }}

select * from source_table
```

---

### Cross-Database Macros

Handle SQL dialect differences across databases.

```jinja
{% macro date_trunc(datepart, date) %}
    {% if target.type == 'snowflake' %}
        date_trunc({{ datepart }}, {{ date }})
    {% elif target.type == 'bigquery' %}
        date_trunc({{ date }}, {{ datepart }})
    {% elif target.type == 'postgres' %}
        date_trunc('{{ datepart }}', {{ date }})
    {% else %}
        {{ exceptions.raise_compiler_error("Unsupported database type: " ~ target.type) }}
    {% endif %}
{% endmacro %}
```

---

### Macro Best Practices

#### ✅ DO

- **Keep macros focused:** One macro = one purpose
- **Use descriptive names:** `cents_to_dollars()` not `convert()`
- **Provide defaults:** Make arguments optional when possible
- **Document complex macros:** Add comments explaining logic
- **Test your macros:** Create sample models to verify behavior
- **Use early returns:** Exit early when conditions aren't met

```jinja
{% macro process_data(table) %}
    {% if not table %}
        {{ return('') }}
    {% endif %}
    
    {# Rest of macro logic #}
{% endmacro %}
```

#### ❌ DON'T

- **Over-abstract:** If used once, maybe don't make it a macro
- **Create monolithic macros:** Break large macros into smaller ones
- **Ignore readability:** Clever code isn't always better
- **Forget the execute flag:** Check `{% if execute %}` for queries

```jinja
{# BAD: Query runs during compilation #}
{% set results = run_query('select * from huge_table') %}

{# GOOD: Query only runs during execution #}
{% if execute %}
    {% set results = run_query('select * from huge_table') %}
{% endif %}
```

---

### Macro Return Values

```jinja
{% macro calculate_discount(amount, rate) %}
    {% set discount = amount * rate %}
    {{ return(discount) }}
{% endmacro %}

{# Use the return value #}
{% set my_discount = calculate_discount(100, 0.15) %}
```

---

### Package Macros

Override package macros by creating a macro with the same name in your project.

```jinja
{# Override dbt_utils.surrogate_key #}
{% macro surrogate_key(field_list) %}
    {{ return(dbt_utils.surrogate_key(field_list)) }}
{% endmacro %}
```

Call package macros explicitly:

```jinja
{{ dbt_utils.group_by(n=3) }}
{{ codegen.generate_source('raw_schema') }}
```

---

## Quick Reference

| Task | Syntax |
|------|--------|
| Define macro | `{% macro name(args) %} ... {% endmacro %}` |
| Call macro | `{{ name(args) }}` |
| Default argument | `{% macro name(arg='default') %}` |
| Return value | `{{ return(value) }}` |
| Run query | `{% set results = run_query(sql) %}` |
| Check execution | `{% if execute %}` |
| Get columns | `adapter.get_columns_in_relation(ref('model'))` |
| Log message | `{{ log('message', info=True) }}` |
| Raise error | `{{ exceptions.raise_compiler_error('error') }}` |
| Access target | `{{ target.name }}`, `{{ target.schema }}` |

---

## Additional Resources

- [dbt Macro Documentation](https://docs.getdbt.com/docs/building-a-dbt-project/jinja-macros)
- [dbt Jinja Functions](https://docs.getdbt.com/reference/dbt-jinja-functions)
- [dbt Utils Package](https://github.com/dbt-labs/dbt-utils) - Library of useful macros
