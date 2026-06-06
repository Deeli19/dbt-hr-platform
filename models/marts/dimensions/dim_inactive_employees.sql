--Grain: 1 row per inactive employee. It is used as a source for other models that need to filter or aggregate by inactive employees.

{{ config(materialized='view') }}

with inactive_employees as (
    
    select *
    
    from {{ ref('int_employee_current_state') }}
    where is_active_employee = false
    
)

select * from inactive_employees