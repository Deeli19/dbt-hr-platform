with employee as (

    select * from {{ ref('dim_employee_current') }}

),

recruitment as (

    select * from {{ ref('fct_recruitment_incremental') }}

),

training as (

    select * from {{ ref('fct_training') }}

),

engagement as (

    select * from {{ ref('fct_engagement_survey') }}

),

employee_kpis as (

    select

        count(*) as total_employees,

        sum(case when is_active_employee then 1 else 0 end)
            as active_employees,

        sum(case when is_terminated_employee = 1 then 1 else 0 end)
            as terminated_employees

    from employee

),

recruitment_kpis as (

    select

        count(*) as total_applications,

        sum(hired_flag) as total_hires,

        avg(desired_salary) as avg_desired_salary

    from recruitment

),

training_kpis as (

    select

        count(*) as total_training_events,

        sum(training_cost) as total_training_cost,

        avg(training_days) as avg_training_duration_days

    from training

),

engagement_kpis as (

    select

        avg(engagement_score) as avg_engagement_score,

        avg(satisfaction_score) as avg_satisfaction_score,

        avg(work_life_balance_score)
            as avg_work_life_balance_score

    from engagement

),

final as (

    select

        -- workforce
        e.total_employees,
        e.active_employees,
        e.terminated_employees,

        -- recruitment
        r.total_applications,
        r.total_hires,
        r.avg_desired_salary,

        -- training
        t.total_training_events,
        t.total_training_cost,
        t.avg_training_duration_days,

        -- engagement
        g.avg_engagement_score,
        g.avg_satisfaction_score,
        g.avg_work_life_balance_score

    from employee_kpis e
    cross join recruitment_kpis r
    cross join training_kpis t
    cross join engagement_kpis g

)

select * from final