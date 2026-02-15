# dbt Packages

Packages are a tool for importing models and macros into your dbt project. These may have been written by a coworker or someone else in the dbt community. Packages enable code reuse and sharing of best practices across the dbt community.

---

## What Are Packages?

Packages can contain:
- ✅ **Macros** - Reusable functions and utilities
- ✅ **Models** - Pre-built data transformations
- ✅ **Tests** - Custom generic tests
- ✅ **Documentation** - Project documentation
- ✅ **Seeds** - Reference data

---

## Package Sources

Packages can be imported from multiple sources:

| Source | Description | Use Case |
|--------|-------------|----------|
| **dbt Hub** | [hub.getdbt.com](https://hub.getdbt.com) | Community-maintained open-source packages |
| **GitHub** | Direct GitHub repository URL | Private or public GitHub repos |
| **GitLab** | Direct GitLab repository URL | Private or public GitLab repos |
| **Local** | Subfolder in your dbt project | Internal shared code |

---

## Installing Packages

### Step 1: Create packages.yml

Create a `packages.yml` file in the root of your dbt project.

**File:** `packages.yml`

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 0.9.6
  
  - package: calogica/dbt_expectations
    version: 0.10.0
```

### Step 2: Install Packages

Run the following command to install all packages:

```bash
dbt deps
```

This command:
- Downloads packages to the `dbt_packages/` directory
- Resolves dependencies between packages
- Makes macros and models available to your project

### Step 3: Use the Package

After installation, all macros and models from the package are available in your project.

---

## Package Configuration Methods

### 1. Hub Package (Recommended)

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 0.9.6
```

### 2. Git Package (GitHub)

```yaml
packages:
  - git: "https://github.com/dbt-labs/dbt-utils.git"
    revision: 0.9.6
```

### 3. Git Package (GitLab)

```yaml
packages:
  - git: "https://gitlab.com/your-org/your-package.git"
    revision: main
```

### 4. Local Package

```yaml
packages:
  - local: packages/my_local_package
```

### 5. Private Git with SSH

```yaml
packages:
  - git: "git@github.com:my-org/private-package.git"
    revision: 0.1.0
```

---

## Using Macros from Packages

After importing a package, your dbt project has access to all the macros from that package.

### Syntax

```jinja
{{ package_name.macro_name(arguments) }}
```

### Example: dbt_utils.date_spine

```sql
{{ dbt_utils.date_spine(
    datepart="day",
    start_date="to_date('01/01/2016', 'mm/dd/yyyy')",
    end_date="dateadd(week, 1, current_date)"
) }}
```

### Example: dbt_utils.surrogate_key

```sql
select
    {{ dbt_utils.surrogate_key(['customer_id', 'order_id']) }} as unique_key,
    customer_id,
    order_id,
    order_date
from {{ ref('stg_orders') }}
```

### Example: dbt_utils.group_by

```sql
select
    customer_id,
    order_date,
    count(*) as order_count,
    sum(order_total) as total_spent
from {{ ref('stg_orders') }}
{{ dbt_utils.group_by(2) }}
```

---

## Using Models from Packages

After importing a package, all models from that package become part of your dbt project.

**What happens:**
- ✅ Models are built when you run `dbt run`
- ✅ Models appear in your dbt documentation
- ✅ Models are visible in your DAG
- ✅ Models can be referenced with `ref()`

**Example:** The snowflake_spend package adds models that appear in your DAG in gray.

### Referencing Package Models

```sql
select *
from {{ ref('package_model_name') }}
```

---

## Popular dbt Packages

### 1. dbt_utils

The most popular dbt package with general-purpose macros.

**Installation:**
```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 0.9.6
```

**Common Macros:**
- `surrogate_key()` - Generate surrogate keys
- `group_by(n)` - Simplify GROUP BY clauses
- `pivot()` - Create pivot tables
- `union_relations()` - Union multiple tables
- `get_column_values()` - Get distinct values from a column
- `star()` - Select all columns with exclusions
- `date_spine()` - Generate date sequences

**Example:**
```sql
{{ dbt_utils.star(from=ref('stg_customers'), except=["password", "ssn"]) }}
```

### 2. dbt_expectations

Data quality tests inspired by Great Expectations.

**Installation:**
```yaml
packages:
  - package: calogica/dbt_expectations
    version: 0.10.0
```

**Common Tests:**
- `expect_column_values_to_be_between`
- `expect_column_values_to_match_regex`
- `expect_table_row_count_to_equal`
- `expect_column_values_to_be_in_set`

**Example:**
```yaml
models:
  - name: orders
    columns:
      - name: order_total
        tests:
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 1000000
```

### 3. dbt_date

Date manipulation and calendar utilities.

**Installation:**
```yaml
packages:
  - package: calogica/dbt_date
    version: 0.10.0
```

**Common Macros:**
- `get_fiscal_year()` - Get fiscal year
- `day_name()` - Get day name
- `n_days_ago()` - Date N days ago
- `n_weeks_ago()` - Date N weeks ago

### 4. codegen

Code generation utilities for dbt.

**Installation:**
```yaml
packages:
  - package: dbt-labs/codegen
    version: 0.12.0
```

**Common Macros:**
- `generate_source()` - Generate source YAML
- `generate_base_model()` - Generate staging model SQL
- `generate_model_yaml()` - Generate model YAML

**Example:**
```sql
-- Generate source YAML
{{ codegen.generate_source('raw_schema') }}

-- Generate base model
{{ codegen.generate_base_model('raw_schema', 'raw_table') }}
```

### 5. dbt_audit_helper

Compare data between models/tables.

**Installation:**
```yaml
packages:
  - package: dbt-labs/audit_helper
    version: 0.9.0
```

**Common Macros:**
- `compare_relations()` - Compare two tables
- `compare_column_values()` - Compare specific columns
- `compare_relation_columns()` - Compare table schemas

### 6. dbt_project_evaluator

Evaluate your dbt project structure and best practices.

**Installation:**
```yaml
packages:
  - package: dbt-labs/dbt_project_evaluator
    version: 0.8.0
```

**Usage:**
```bash
dbt run --select dbt_project_evaluator
```

---

## Package Version Control

### Semantic Versioning

```yaml
packages:
  # Exact version
  - package: dbt-labs/dbt_utils
    version: 0.9.6
  
  # Version range
  - package: dbt-labs/dbt_utils
    version: [">=0.9.0", "<1.0.0"]
  
  # Latest version (not recommended for production)
  - package: dbt-labs/dbt_utils
    version: latest
```

### Git Revisions

```yaml
packages:
  # Specific tag
  - git: "https://github.com/dbt-labs/dbt-utils.git"
    revision: 0.9.6
  
  # Specific branch
  - git: "https://github.com/dbt-labs/dbt-utils.git"
    revision: main
  
  # Specific commit
  - git: "https://github.com/dbt-labs/dbt-utils.git"
    revision: abc123def456
```

---

## Advanced Package Configurations

### Installing to a Specific Path

By default, packages install to `dbt_packages/`. To change this:

**dbt_project.yml:**
```yaml
packages-install-path: custom_packages
```

### Excluding Package Models

To prevent package models from running:

**dbt_project.yml:**
```yaml
models:
  package_name:
    +enabled: false
```

### Overriding Package Variables

Many packages accept configuration variables:

**dbt_project.yml:**
```yaml
vars:
  'dbt_date:time_zone': 'America/New_York'
  'dbt_utils:dispatch_list': ['snowflake_utils']
```

### Using Specific Package Macros

When multiple packages have macros with the same name:

```jinja
{{ dbt_utils.date_spine(...) }}  {# Explicit package reference #}
```

---

## Package Development

### Creating Your Own Package

**Structure:**
```
my_package/
├── dbt_project.yml
├── macros/
│   ├── macro1.sql
│   └── macro2.sql
├── models/
│   ├── model1.sql
│   └── schema.yml
└── README.md
```

**dbt_project.yml:**
```yaml
name: 'my_package'
version: '0.1.0'
config-version: 2
```

### Testing Package Locally

```yaml
packages:
  - local: ../my_local_package
```

### Dispatching Macros

Allow users to override your macros:

```jinja
{% macro default__my_macro() %}
    -- Default implementation
{% endmacro %}

{% macro snowflake__my_macro() %}
    -- Snowflake-specific implementation
{% endmacro %}

{# Usage #}
{{ adapter.dispatch('my_macro', 'my_package')() }}
```

---

## Package Management Commands

```bash
# Install packages
dbt deps

# Clean installed packages
dbt clean

# Install and run
dbt deps && dbt run

# Update package (change version in packages.yml, then run)
dbt deps
```

---

## Packages Cheat Sheet

### Quick Reference

| Task | Command/Code |
|------|--------------|
| Install packages | `dbt deps` |
| Create packages file | Create `packages.yml` in root |
| Use package macro | `{{ package.macro_name() }}` |
| Reference package model | `{{ ref('package_model') }}` |
| Clean packages | `dbt clean` |
| Hub package | `package: dbt-labs/dbt_utils` |
| Git package | `git: "https://github.com/..."` |
| Local package | `local: path/to/package` |
| Specific version | `version: 0.9.6` |
| Version range | `version: [">=0.9.0", "<1.0.0"]` |

### Common dbt_utils Macros

```jinja
{# Surrogate key #}
{{ dbt_utils.surrogate_key(['id', 'created_at']) }}

{# Group by #}
{{ dbt_utils.group_by(3) }}

{# Star with exclusions #}
{{ dbt_utils.star(from=ref('model'), except=["col1", "col2"]) }}

{# Pivot #}
{{ dbt_utils.pivot('category', dbt_utils.get_column_values(ref('model'), 'category')) }}

{# Union relations #}
{{ dbt_utils.union_relations(relations=[ref('table1'), ref('table2')]) }}

{# Get column values #}
{% set statuses = dbt_utils.get_column_values(ref('orders'), 'status') %}

{# Date spine #}
{{ dbt_utils.date_spine(
    datepart="day",
    start_date="cast('2020-01-01' as date)",
    end_date="current_date"
) }}

{# Generate series #}
{{ dbt_utils.generate_series(upper_bound=10) }}

{# Deduplicate #}
{{ dbt_utils.deduplicate(
    relation=ref('source'),
    partition_by='user_id',
    order_by='updated_at desc'
) }}
```

### Common Package Patterns

#### Pattern 1: Using Multiple Packages

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 0.9.6
  - package: calogica/dbt_expectations
    version: 0.10.0
  - package: dbt-labs/codegen
    version: 0.12.0
```

#### Pattern 2: Mix Hub and Git Packages

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 0.9.6
  - git: "https://github.com/your-org/internal-package.git"
    revision: main
```

#### Pattern 3: Local Development

```yaml
packages:
  - local: ../packages/shared_macros
  - package: dbt-labs/dbt_utils
    version: 0.9.6
```

---

## Best Practices

### ✅ DO

1. **Pin specific versions in production**
   ```yaml
   packages:
     - package: dbt-labs/dbt_utils
       version: 0.9.6  # Specific version, not "latest"
   ```

2. **Review package documentation**
   - Always read the README before using a package
   - Check compatibility with your dbt version

3. **Test after updating packages**
   ```bash
   dbt deps
   dbt build --select state:modified+
   ```

4. **Use semantic versioning**
   ```yaml
   version: [">=0.9.0", "<1.0.0"]  # Allow patches, prevent breaking changes
   ```

5. **Document package dependencies**
   - Note why each package is needed
   - Document which macros you're using

### ❌ DON'T

1. **Don't use "latest" in production**
   ```yaml
   # BAD
   version: latest
   
   # GOOD
   version: 0.9.6
   ```

2. **Don't commit dbt_packages/ directory**
   - Add to `.gitignore`
   - Similar to node_modules or venv

3. **Don't modify package code directly**
   - Changes will be lost on `dbt deps`
   - Create a wrapper macro instead

4. **Don't install unnecessary packages**
   - Each package adds complexity
   - Only install what you actively use

---

## Troubleshooting

### Issue: "Package not found"

**Solution:**
```bash
dbt clean
dbt deps
```

### Issue: "Macro conflicts"

**Solution:** Use explicit package references
```jinja
{{ dbt_utils.date_spine(...) }}  {# Not just date_spine(...) #}
```

### Issue: "Version conflicts"

**Solution:** Check package compatibility matrix in documentation

### Issue: "Package models not running"

**Solution:**
```yaml
models:
  package_name:
    +enabled: true
```

---

## Resources

- [dbt Hub](https://hub.getdbt.com) - Browse available packages
- [dbt Packages Documentation](https://docs.getdbt.com/docs/build/packages)
- [dbt_utils GitHub](https://github.com/dbt-labs/dbt-utils) - Most popular package
- [Package Development Guide](https://docs.getdbt.com/guides/legacy/building-packages)
