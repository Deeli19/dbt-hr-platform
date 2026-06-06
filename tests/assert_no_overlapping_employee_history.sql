with employee_history as (

    select
        employee_id,
        effective_start_date,
        effective_end_date,

        lag(effective_end_date) over (
            partition by employee_id
            order by effective_start_date
        ) as previous_effective_end_date

    from {{ ref('int_employee_state_changes') }}

),

validation as (

    select *
    from employee_history

    where effective_start_date < previous_effective_end_date

)

select *
from validation