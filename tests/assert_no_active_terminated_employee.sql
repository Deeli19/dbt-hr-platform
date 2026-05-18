select *
from {{ ref('fct_employee_history') }}

where employee_status = 'terminated'
  and is_active_employee = true