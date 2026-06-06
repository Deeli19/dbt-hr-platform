{{ warn_deprecated_model(
    'int_employee_status_changes_v1',
    'int_employee_status_changes_v2'
) }}


with employee_history as (
    
    select * from {{ ref('employee_snapshot') }}
),

history_enriched as (

    select
        {{ dbt_utils.generate_surrogate_key([
        'employee_id','dbt_valid_from']) }} as employee_history_id,
        employee_id,
        first_name,
        last_name,
        employee_status,
        title,
        division,
        department_type,
        supervisor,
        dbt_valid_from as effective_start_date,
        dbt_valid_to as effective_end_date,

        datediff(
            'day',
            dbt_valid_from,
            coalesce(dbt_valid_to, current_timestamp())
        ) as days_in_state, -- calculates the number of days an employee has been in a particular state (e.g., title, department, etc.) based on the valid from and to dates. If dbt_valid_to is null, it uses the current timestamp to calculate the tenure in that state.

        case 
            when dbt_valid_to is null then true
            else false
        end as is_current_record

    from employee_history
),

history_with_previous_state as (

    select *,

        lag(employee_status) over (
        partition by employee_id
        order by effective_start_date
        ) as previous_employee_status,

         lag(title) over (
        partition by employee_id
        order by effective_start_date
        ) as previous_title,

        lag(division) over (
        partition by employee_id
        order by effective_start_date
        ) as previous_division,         

        lag(department_type) over (
        partition by employee_id
        order by effective_start_date
        ) as previous_department_type,        

        lag(supervisor) over (
        partition by employee_id
        order by effective_start_date
        ) as previous_supervisor

    from history_enriched
)

select * from history_with_previous_state