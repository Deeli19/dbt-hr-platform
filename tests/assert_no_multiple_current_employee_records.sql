select
    employee_id
from {{ ref('employee_snapshot') }}
where dbt_valid_to is null
group by employee_id
having count(*) > 1