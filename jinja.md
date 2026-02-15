# Jinja in dbt

Jinja is a templating language written in Python. Jinja is used in dbt to write functional SQL, enabling dynamic and reusable code. For example, you can write a dynamic pivot model using Jinja.

---

## Jinja Basics

The best place to learn about leveraging Jinja is the [Jinja Template Designer documentation](https://jinja.palletsprojects.com/en/stable/templates/).

### Three Jinja Delimiters

| Delimiter | Purpose | Description |
|-----------|---------|-------------|
| `{% ... %}` | **Statements** | Perform function programming such as setting variables or starting loops |
| `{{ ... }}` | **Expressions** | Print text to the rendered file (compiles Jinja to pure SQL) |
| `{# ... #}` | **Comments** | Document code inline (not rendered in compiled SQL) |

---

## Core Features

### 1. Dictionaries

Dictionaries are data structures composed of key-value pairs.

**Code:**
```jinja
{% set person = {
    'name': 'me',
    'number': 3
} %}

{{ person.name }}
{{ person['number'] }}
```

**Output:**
```
me
3
```

---

### 2. Lists

Lists are data structures that are ordered and indexed by integers.

**Code:**
```jinja
{% set self = ['me', 'myself'] %}

{{ self[0] }}
```

**Output:**
```
me
```

---

### 3. If/Else Statements

Control statements that make it possible to provide instructions for decision-making based on clear criteria.

**Code:**
```jinja
{% set temperature = 80.0 %}

On a day like this, I especially like

{% if temperature > 70.0 %}
a refreshing mango sorbet.
{% else %}
a decadent chocolate ice cream.
{% endif %}
```

**Output:**
```
On a day like this, I especially like
a refreshing mango sorbet.
```

---

### 4. For Loops

Make it possible to repeat a code block while passing different values for each iteration.

**Code:**
```jinja
{% set flavors = ['chocolate', 'vanilla', 'strawberry'] %}

{% for flavor in flavors %}
Today I want {{ flavor }} ice cream!
{% endfor %}
```

**Output:**
```
Today I want chocolate ice cream!
Today I want vanilla ice cream!
Today I want strawberry ice cream!
```

---

### 5. Macros

Macros are a way of writing functions in Jinja. This allows you to write a set of statements once and then reference them throughout your code base.

**Code:**
```jinja
{% macro hoyquiero(flavor, dessert = 'ice cream') %}
Today I want {{ flavor }} {{ dessert }}!
{% endmacro %}

{{ hoyquiero(flavor = 'chocolate') }}
{{ hoyquiero('mango', 'sorbet') }}
```

**Output:**
```
Today I want chocolate ice cream!
Today I want mango sorbet!
```

---

### 6. Whitespace Control

Control whitespace by adding a single dash (`-`) on either side of the Jinja delimiter. This trims the whitespace between the Jinja delimiter on that side of the expression.

**Example:**
```jinja
{%- for item in items -%}
{{ item }}
{%- endfor -%}
```

---

## Practical Example: Dynamic Pivot Model

This example shows how to refactor a static pivot model into a dynamic one using Jinja.

### Original SQL (Static)

```sql
with payments as (
   select * from {{ ref('stg_payments') }}
),
 
final as (
   select
       order_id,
 
       sum(case when payment_method = 'bank_transfer' then amount else 0 end) as bank_transfer_amount,
       sum(case when payment_method = 'credit_card' then amount else 0 end) as credit_card_amount,
       sum(case when payment_method = 'coupon' then amount else 0 end) as coupon_amount,
       sum(case when payment_method = 'gift_card' then amount else 0 end) as gift_card_amount
 
   from payments
 
   group by 1
)
 
select * from final
```

### Refactored Jinja + SQL (Dynamic)

```sql
{%- set payment_methods = ['bank_transfer','credit_card','coupon','gift_card'] -%}
 
with payments as (
   select * from {{ ref('stg_payments') }}
),
 
final as (
   select
       order_id,
       {% for payment_method in payment_methods -%}
 
       sum(case when payment_method = '{{ payment_method }}' then amount else 0 end) 
            as {{ payment_method }}_amount
          
       {%- if not loop.last -%}
         ,
       {% endif -%}
 
       {%- endfor %}
   from payments
   group by 1
)
 
select * from final
```

**Benefits:**
- ✅ Easy to add/remove payment methods by updating the list
- ✅ Eliminates repetitive code
- ✅ Reduces maintenance burden
- ✅ More readable and maintainable

---

## Jinja Cheat Sheet

### Variables

```jinja
{# Set a variable #}
{% set my_variable = 'value' %}
{% set my_number = 42 %}
{% set my_list = ['a', 'b', 'c'] %}
{% set my_dict = {'key': 'value', 'number': 1} %}

{# Use a variable #}
{{ my_variable }}
```

### Conditionals

```jinja
{# Basic if/else #}
{% if condition %}
    do something
{% endif %}

{# If/elif/else #}
{% if condition1 %}
    do something
{% elif condition2 %}
    do something else
{% else %}
    default action
{% endif %}

{# Inline if (ternary) #}
{{ 'yes' if condition else 'no' }}
```

### Loops

```jinja
{# Basic for loop #}
{% for item in items %}
    {{ item }}
{% endfor %}

{# Loop with index #}
{% for item in items %}
    {{ loop.index }}: {{ item }}
{% endfor %}

{# Loop with conditional #}
{% for item in items if item.active %}
    {{ item.name }}
{% endfor %}
```

### Loop Variables

| Variable | Description |
|----------|-------------|
| `loop.index` | Current iteration (1-indexed) |
| `loop.index0` | Current iteration (0-indexed) |
| `loop.first` | True if first iteration |
| `loop.last` | True if last iteration |
| `loop.length` | Total number of items |
| `loop.cycle` | Helper to cycle between values |

### Macros

```jinja
{# Define a macro #}
{% macro my_macro(arg1, arg2='default') %}
    {{ arg1 }} and {{ arg2 }}
{% endmacro %}

{# Call a macro #}
{{ my_macro('value1', 'value2') }}
{{ my_macro('value1') }}

{# Import macros from another file #}
{% import 'macros.sql' as macros %}
{{ macros.my_macro('value') }}
```

### Filters

```jinja
{# String operations #}
{{ my_string | upper }}
{{ my_string | lower }}
{{ my_string | trim }}
{{ my_string | replace('old', 'new') }}

{# List operations #}
{{ my_list | length }}
{{ my_list | join(', ') }}
{{ my_list | first }}
{{ my_list | last }}

{# Default values #}
{{ my_variable | default('fallback') }}

{# Type conversions #}
{{ my_value | int }}
{{ my_value | float }}
{{ my_value | string }}
```

### Tests

```jinja
{# Check conditions #}
{% if variable is defined %}
{% if variable is none %}
{% if variable is number %}
{% if variable is string %}
{% if variable is iterable %}

{# Negation #}
{% if variable is not none %}
```

### Whitespace Control

```jinja
{# Remove whitespace before #}
{%- if condition %}

{# Remove whitespace after #}
{% if condition -%}

{# Remove whitespace on both sides #}
{%- if condition -%}
```

### Comments

```jinja
{# Single line comment #}

{#
   Multi-line
   comment
#}
```

---

## dbt-Specific Jinja

### Core Functions

```jinja
{# Reference models #}
{{ ref('model_name') }}

{# Reference sources #}
{{ source('source_name', 'table_name') }}

{# Get configuration #}
{{ config(materialized='table') }}

{# Run queries and return results #}
{% set results = run_query('select * from table') %}

{# Access context variables #}
{{ target.name }}
{{ target.schema }}
{{ target.type }}

{# Check execution context #}
{% if execute %}
    {# This runs during execution phase #}
{% endif %}

{# Get column names from a relation #}
{% set columns = adapter.get_columns_in_relation(ref('model')) %}
```

### Target Context Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `target.name` | Target name from profiles.yml | `dev`, `prod` |
| `target.schema` | Target schema | `dbt_john` |
| `target.type` | Database type | `postgres`, `snowflake`, `bigquery` |
| `target.database` | Database name | `analytics` |
| `target.user` | Database user | `dbt_user` |
| `target.threads` | Number of threads | `4` |

### Adapter Functions

```jinja
{# Check if relation exists #}
{% set relation_exists = adapter.get_relation(
    database=target.database,
    schema='my_schema',
    identifier='my_table'
) %}

{# Get columns from a relation #}
{% set columns = adapter.get_columns_in_relation(ref('my_model')) %}

{# Check table type #}
{% if adapter.get_relation().type == 'view' %}

{# Create relation object #}
{% set my_relation = adapter.get_relation(
    database='db',
    schema='schema',
    identifier='table'
) %}
```

---

## Common Patterns

### Dynamic Column Selection

```jinja
{% set columns_to_select = ['col1', 'col2', 'col3'] %}

select
    {% for col in columns_to_select %}
    {{ col }}{{ ',' if not loop.last }}
    {% endfor %}
from table
```

### Conditional Table References

```jinja
{% if target.name == 'prod' %}
    {% set source_table = 'prod_schema.table' %}
{% else %}
    {% set source_table = 'dev_schema.table' %}
{% endif %}

select * from {{ source_table }}
```

### Generate Date Spine

```jinja
{% for i in range(30) %}
    select 
        current_date - {{ i }} as date_day
    {{ 'union all' if not loop.last }}
{% endfor %}
```

### Dynamic CASE Statements

```jinja
{% set categories = ['A', 'B', 'C'] %}

case
    {% for cat in categories %}
    when category = '{{ cat }}' then '{{ cat }}_processed'
    {% endfor %}
    else 'other'
end as processed_category
```

### Get Unique Values from Table

```jinja
{% set payment_methods_query %}
    select distinct payment_method
    from {{ ref('stg_payments') }}
    order by payment_method
{% endset %}

{% if execute %}
    {% set results = run_query(payment_methods_query) %}
    {% set payment_methods = results.columns[0].values() %}
{% else %}
    {% set payment_methods = [] %}
{% endif %}

{# Use the values #}
select
    {% for method in payment_methods %}
    sum(case when payment_method = '{{ method }}' then amount end) as {{ method }}_amount
    {{- ',' if not loop.last }}
    {% endfor %}
from {{ ref('stg_payments') }}
```

### Union Multiple Tables

```jinja
{% set tables = ['orders_2023', 'orders_2024', 'orders_2025'] %}

{% for table in tables %}
    select 
        '{{ table }}' as source_table,
        *
    from {{ ref(table) }}
    {{ 'union all' if not loop.last }}
{% endfor %}
```

### Exclude Columns from SELECT *

```jinja
{% set exclude_cols = ['password', 'ssn', 'credit_card'] %}
{% set all_columns = adapter.get_columns_in_relation(ref('users')) %}

select
    {% for col in all_columns if col.name not in exclude_cols %}
    {{ col.name }}{{ ',' if not loop.last }}
    {% endfor %}
from {{ ref('users') }}
```

### Environment-Specific Configuration

```jinja
{{ config(
    materialized='incremental' if target.name == 'prod' else 'table',
    unique_key='id',
    tags=['daily'] if target.name == 'prod' else ['hourly']
) }}

select * from source_table
```

### Generate Schema Name

```jinja
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

---

## Best Practices

### ✅ DO

1. **Use whitespace control** when generating clean SQL
   ```jinja
   {%- for item in items -%}
   {{ item }}
   {%- endfor -%}
   ```

2. **Check execute flag** before running queries
   ```jinja
   {% if execute %}
       {% set results = run_query(sql) %}
   {% endif %}
   ```

3. **Use descriptive variable names**
   ```jinja
   {% set payment_methods = [...] %}  {# Good #}
   {% set pm = [...] %}  {# Bad #}
   ```

4. **Add comments to complex logic**
   ```jinja
   {# Calculate running total for each category #}
   {% for category in categories %}
       ...
   {% endfor %}
   ```

5. **Handle edge cases**
   ```jinja
   {% if items | length > 0 %}
       {# Process items #}
   {% else %}
       {# Handle empty list #}
   {% endif %}
   ```

### ❌ DON'T

1. **Don't run queries during compilation**
   ```jinja
   {# BAD: Runs during compilation #}
   {% set results = run_query('select * from huge_table') %}
   
   {# GOOD: Only runs during execution #}
   {% if execute %}
       {% set results = run_query('select * from huge_table') %}
   {% endif %}
   ```

2. **Don't overcomplicate with Jinja**
   - If the SQL is simple, keep it simple
   - Balance DRY principles with readability

3. **Don't forget loop.last**
   ```jinja
   {# BAD #}
   {% for item in items %}
   {{ item }},
   {% endfor %}
   
   {# GOOD #}
   {% for item in items %}
   {{ item }}{{ ',' if not loop.last }}
   {% endfor %}
   ```

---

## Quick Reference

| Task | Syntax |
|------|--------|
| Set variable | `{% set var = 'value' %}` |
| Print expression | `{{ expression }}` |
| If statement | `{% if condition %} ... {% endif %}` |
| For loop | `{% for item in items %} ... {% endfor %}` |
| Comment | `{# comment #}` |
| Define macro | `{% macro name(args) %} ... {% endmacro %}` |
| Call macro | `{{ macro_name(args) }}` |
| Apply filter | `{{ value \| filter }}` |
| Check if defined | `{% if var is defined %}` |
| Whitespace control | `{%- ... -%}` |
| Reference model | `{{ ref('model') }}` |
| Reference source | `{{ source('name', 'table') }}` |
| Run query | `{% set r = run_query(sql) %}` |
| Target variable | `{{ target.name }}` |

---

## References

- [Jinja Template Designer Documentation](https://jinja.palletsprojects.com/en/stable/templates/)
- [dbt Jinja Function Reference](https://docs.getdbt.com/reference/dbt-jinja-functions)
- [dbt Docs - Using Jinja](https://docs.getdbt.com/docs/build/jinja-macros)
