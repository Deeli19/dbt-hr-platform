-- Grain: 1 row per employee event (hire, termination, title change, etc.)

with employee_changes as (

    select *

    from {{ ref('int_employee_state_changes') }}

),

initial_hire_events as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'employee_id',
            'effective_start_date',
            "'hire_event'"
        ]) }} as employee_event_id,

        employee_id,
        employee_history_id,

        effective_start_date as event_timestamp,
        cast(effective_start_date as date) as event_date,

        'hire_event' as event_type,

        null as previous_value,
        employee_status as new_value,

        'employee_status' as changed_attribute

    from employee_changes

    where previous_employee_status is null

),

employee_status_events as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'employee_id',
            'effective_start_date',
            "'employee_status_change'"
        ]) }} as employee_event_id,

        employee_id,
        employee_history_id,

        effective_start_date as event_timestamp,
        cast(effective_start_date as date) as event_date,

        'employee_status_change' as event_type,

        previous_employee_status as previous_value,
        employee_status as new_value,

        'employee_status' as changed_attribute

    from employee_changes

    where coalesce(previous_employee_status, 'unknown')
        != coalesce(employee_status, 'unknown')

),

title_change_events as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'employee_id',
            'effective_start_date',
            "'title_change'"
        ]) }} as employee_event_id,

        employee_id,
        employee_history_id,

        effective_start_date as event_timestamp,
        cast(effective_start_date as date) as event_date,

        'title_change' as event_type,

        previous_title as previous_value,
        title as new_value,

        'title' as changed_attribute

    from employee_changes

    where coalesce(previous_title, 'unknown')
        != coalesce(title, 'unknown')

),

division_transfer_events as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'employee_id',
            'effective_start_date',
            "'division_transfer'"
        ]) }} as employee_event_id,

        employee_id,
        employee_history_id,

        effective_start_date as event_timestamp,
        cast(effective_start_date as date) as event_date,

        'division_transfer' as event_type,

        previous_division as previous_value,
        division as new_value,

        'division' as changed_attribute

    from employee_changes

    where coalesce(previous_division, 'unknown')
        != coalesce(division, 'unknown')

),

department_change_events as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'employee_id',
            'effective_start_date',
            "'department_type_change'"
        ]) }} as employee_event_id,

        employee_id,
        employee_history_id,

        effective_start_date as event_timestamp,
        cast(effective_start_date as date) as event_date,

        'department_type_change' as event_type,

        previous_department_type as previous_value,
        department_type as new_value,

        'department_type' as changed_attribute

    from employee_changes

    where coalesce(previous_department_type, 'unknown')
        != coalesce(department_type, 'unknown')

),

supervisor_change_events as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'employee_id',
            'effective_start_date',
            "'supervisor_change'"
        ]) }} as employee_event_id,

        employee_id,
        employee_history_id,

        effective_start_date as event_timestamp,
        cast(effective_start_date as date) as event_date,

        'supervisor_change' as event_type,

        previous_supervisor as previous_value,
        supervisor as new_value,

        'supervisor' as changed_attribute

    from employee_changes

    where coalesce(previous_supervisor, 'unknown')
        != coalesce(supervisor, 'unknown')

),

final as (

    select * from initial_hire_events

    union all

    select * from employee_status_events

    union all

    select * from title_change_events

    union all

    select * from division_transfer_events

    union all

    select * from department_change_events

    union all

    select * from supervisor_change_events

)

select *

from final