-- Grain: 1 row per employee per month, but only on the archive day of the month (e.g. 1st of the month). This allows us to keep a historical record of employee attributes on a monthly basis without having to run a full snapshot every day.

{{ 
    config(
    materialized='incremental',
    incremental_strategy='append',
    on_schema_change='sync_all_columns'
    )
}}

{% set archive_day = var('archive_day', default=1) %}

{% set archive_date = run_started_at.strftime('%Y-%m-%d') %} 

with employee_data as (

    select 
        *,
        cast('{{ archive_date }}' as date) as archive_date
    from {{ ref('int_employee_identity') }}
),

rows_to_archive as (

    select *
    from employee_data

        {% if is_incremental() %}

        where not exists (
            select 1
            from {{ this }}
            where {{ this }}.employee_id = employee_data.employee_id
            and {{ this }}.archive_date = employee_data.archive_date
        )
    {% endif %}

)

{% if is_archive_day(archive_day) %}
    
    select *

    from rows_to_archive

{% else %}

    -- Not archive day, so return no rows to archive. This allows the model to run daily without archiving every day.
    select *
    from rows_to_archive
    where 1=0

{% endif %}