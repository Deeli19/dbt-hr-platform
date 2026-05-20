with source as (

    select * 
    from {{ source('hr', 'employee_engagement_survey') }}

),

renamed as (

    select
        -- primary key
        employee_id,

        -- dates
        try_to_date(survey_date, 'DD-MM-YYYY') as survey_date,

        -- categorical
        engagement_score,
        satisfaction_score,
        work_life_balance_score

    from source

)

select * from renamed