with training as (

    select * from {{ ref('stg_hr__training') }}

),

final as (

    select

        employee_id,
        training_date,

        training_name,
        training_type,
        trainer,
        location,

        training_days,
        training_cost,

        training_outcome

    from training

)

select * from final