with source as (

    select * 
    from {{ source('hr', 'training_and_development') }}

),

renamed as (

    select
        -- primary key
        employee_id,

        -- dates
        try_to_date(training_date, 'DD-MON-YYYY') as training_date,

        -- categorical
        training_program_name as training_name,
        training_type,
        training_outcome,
        location,
        trainer,

        -- numerical
        training_duration_days as training_days,
        training_cost

    from source

)

select * from renamed