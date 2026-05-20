{{ 
    config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='applicant_id',
    on_schema_change='fail',
    cluster_by=['application_date'],
    merge_update_columns=[
        'application_status',
        'dbt_updated_at'
        ]
    )
}}


with recruitment as (

    select * from {{ ref('stg_hr__recruitment') }}

        {% if is_incremental() %}

        where application_date > 
            dateadd(
                days, 
                -3,
                coalesce(
                    (select max(application_date) from {{ this }}),
                    '1900-01-01'
                    ) -- Incremental filter includes 3-day lookback window to handle late-arriving data
            ) -- null protection for late-arriving logic to avoid empty table on first run
    {% endif %}

),

final as (

    select

        applicant_id,
        application_date,
        application_status,
        job_title,
        years_of_experience,
        desired_salary,

        case
            when application_status = 'Offered' then 1
            else 0
        end as hired_flag,
        
        current_timestamp() as dbt_updated_at,
        'dbt_incremental_merge' as record_source

    from recruitment

)

select * from final