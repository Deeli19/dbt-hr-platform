with source as (

    select * 
    from {{ source('hr', 'recruitment') }}

),

renamed as (

    select
        -- primary key
        applicant_id,

        -- text fields
        lower(trim(first_name)) as first_name,
        lower(trim(last_name)) as last_name,

        -- email
        lower(trim(email)) as email,

        -- dates
        {{ parse_date('application_date', 'DD-MON-YY') }} as application_date,
        to_date(date_of_birth, 'DD-MM-YYYY') as date_of_birth,

        -- categorical
        status as application_status,
        job_title,
        years_of_experience,

        -- numerical
        desired_salary,

        -- metadata
        current_timestamp as _loaded_at

    from source

)

select * from renamed