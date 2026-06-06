--Grain: 1 row per active employee. This is a dimension table that captures the current state of active employees in the organization. It is used as a source for other models that need to filter or aggregate by active employees.

{{ config(materialized='view') }}

with active_employees as (
    
    select *
    
    from {{ ref('int_employee_current_state') }}
    where is_active_employee = true
    
)

select * from active_employees