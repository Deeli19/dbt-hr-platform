select
    employee_id
from {{ ref('int_employee_current_state') }}
where is_active_employee = true
and employment_exit_date is not null