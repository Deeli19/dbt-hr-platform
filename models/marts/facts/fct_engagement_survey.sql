with survey as (

    select * from {{ ref('stg_hr__engagement') }}

),

final as (

    select

        employee_id,
        survey_date,

        engagement_score,
        satisfaction_score,
        work_life_balance_score,

        (
            engagement_score +
            satisfaction_score +
            work_life_balance_score
        ) / 3.0 as overall_employee_sentiment_score

    from survey

)

select * from final