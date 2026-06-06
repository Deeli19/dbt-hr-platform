# HR Analytics Engineering Platform (dbt + Snowflake + GitHub Actions)

## Overview

This project builds a modern People Analytics data platform from the ground up, transforming raw HR data into a reliable, scalable analytics foundation.

It demonstrates how to design and operationalize:

* Data pipelines
* Canonical employee modeling
* Slowly changing dimensions (SCD2)
* Business-ready analytics marts
* Workflow orchestration and CI/CD

---

## Business Problem

HR data is often fragmented across systems (HRIS, recruiting, surveys), making it difficult to answer core questions like:

* What is our true headcount over time?
* How effective is our hiring funnel?
* Where are we losing talent and why?
* How do employee lifecycle changes impact the organization?

This project solves that by building a unified analytics layer with consistent, governed definitions.

---

## Architecture

```
Raw Data (Snowflake)
        ↓
Sources (dbt)
        ↓
Staging Layer (cleaning, typing, standardization)
        ↓
Intermediate Layer (identity resolution)
        ↓
Snapshots (SCD2 employee history)
        ↓
Dimensions & Facts (star schema)
        ↓
Analytics Marts (KPIs, trends)
        ↓
CI/CD (GitHub Actions)
```

---

## Data Modeling Approach

### 1. Canonical Employee Model

* Built a stable `canonical_employee_id`
* Resolves multiple employment records (rehire scenarios)
* Enables longitudinal workforce analysis

### 2. Slowly Changing Dimensions (SCD2)

* Implemented using dbt snapshots
The source employee dataset does not currently contain a reliable
updated_at column. Therefore, dbt snapshot check strategy was used
to detect historical attribute changes.

In a production environment, a timestamp-based strategy would
generally be preferred for scalability and maintainability.
* Tracks changes in:

  * employee_status
  * title
  * division
  * department_type
  * supervisor
* Supports point-in-time reporting

### 3. Star Schema Design

**Dimensions**

* `dim_active_employee`
* `dim_inactive_employee`
* `dim_date`

**Facts**

* `fct_employee_events`
* `fct_employee_monthly_archive`
* `fct_employee_workforce_monthly`
* `fct_engagement_survey`
* `fct_recruitment`
* `fct_training`


---

## Analyses Marts

Built business-facing models including:

* `monthly_hiring_kpis`
* `monthly_workforce_kpis`
* `employee_attrition_analysis`
* `hr_kpi_summary`

These answer real business questions around hiring, retention, and workforce trends.

---

## Incremental Modeling Strategy & Performance Optimization

* Implemented incremental model for recruitment fact table.
to simulate production-scale analytics engineering practices
* Reduced full table rebuilds
* Designed for scalability as data volume grows

### Design Decisions
- Snowflake merge strategy used for idempotent loads
- 3-day lookback window handles late-arriving records
- Incremental filtering based on application_date timestamps
- Tests ensure uniqueness and referential integrity

### Tradeoffs
Incremental models improve runtime and reduce compute
costs but increase pipeline complexity and require
careful state management.

---

## Data Quality & Governance

Implemented dbt tests:

* not_null
* unique
* relationships
* accepted_values
* business logic tests (e.g., exit_date validation)

Ensures trust in analytics outputs.

---

## CI/CD

GitHub Actions pipeline:

* Validates dbt project on every push
* Runs:

  * dbt deps
  * dbt parse
  * dbt build

Prevents broken models from being merged.

---

## Tech Stack

* dbt
* Snowflake
* Prefect
* Python
* GitHub Actions

---

## Key Features

* Canonical employee identity resolution
* Rehire tracking
* SCD2 workforce history
* Incremental pipelines
* Star schema modeling
* End-to-end orchestration
* CI/CD validation

---

## Future Improvements

* Full Snowflake-connected CI pipeline
* Advanced identity resolution (fuzzy matching)
* Workforce hierarchy modeling (manager trees)
* Semantic metrics layer
* BI dashboard integration

---

## How to Run

```bash
dbt deps
dbt seed
dbt snapshot
dbt build
```

Or via Prefect:

```bash
python orchestration/prefect_hr_pipeline.py
```

---

## 👤 Author

Analytics Engineering Project demonstrating end-to-end warehouse design, data modeling, and pipeline orchestration.
