with employee as (

    select * from {{ ref('dim_employee_current') }}

),

employee_start_months as (

    select

        extract(year from employment_start_date) as year,
        extract(month from employment_start_date) as month,

        count(*) as hires

    from employee

    group by 1, 2

),

employee_exit_months as (

    select

        extract(year from employment_exit_date) as year,
        extract(month from employment_exit_date) as month,

        count(*) as terminations

    from employee

    where employment_exit_date is not null

    group by 1, 2

),

final as (

    select

        coalesce(s.year, e.year) as year,
        coalesce(s.month, e.month) as month,

        coalesce(s.hires, 0) as hires,
        coalesce(e.terminations, 0) as terminations

    from employee_start_months s
    full outer join employee_exit_months e
        on s.year = e.year
        and s.month = e.month

)

select *

from final