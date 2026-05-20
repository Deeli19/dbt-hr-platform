with employee as (

    select * from {{ ref('dim_employee_current') }}

),

terminated_employees as (

    select *

    from employee

    where is_terminated_employee = 1

),

final as (

    select

        division,
        department_type,

        count(*) as terminated_employee_count,

        round(avg(tenure_days), 0) as avg_tenure_before_exit

    from terminated_employees

    group by 1, 2

)

select *

from final