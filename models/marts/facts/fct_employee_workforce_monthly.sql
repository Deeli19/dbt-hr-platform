-- Grain: 1 row per month, with monthly counts of hires and terminations. This is a useful fact table for tracking workforce trends over time.

with employee as (

    select *
    from {{ ref('int_employee_current_state') }}

),

hire_events as (

    select

        date_trunc(
            'month',
            employment_start_date
        ) as metric_month,

        count(*) as hires

    from employee

    group by 1

),

termination_events as (

    select

        date_trunc(
            'month',
            employment_exit_date
        ) as metric_month,

        count(*) as terminations

    from employee

    where employment_exit_date is not null

    group by 1

),

final as (

    select

        coalesce(
            h.metric_month,
            t.metric_month
        ) as metric_month,

        coalesce(h.hires,0) as hires,
        coalesce(t.terminations,0) as terminations

    from hire_events h

    full outer join termination_events t
        on h.metric_month = t.metric_month

)

select * from final