with source as (

    select * 
    from {{ source('hr', 'employee') }}

),

renamed as (

    select
        -- primary key
        emp_id as employee_id,

        -- identity
        lower(trim(first_name)) as first_name,
        lower(trim(last_name)) as last_name,
        lower(trim(ad_email)) as email,

        -- employment attributes
        employee_status,
        employee_type,
        employee_classification_type,

        -- dates
        {{ parse_date('start_date', 'DD-MON-YY') }} as employment_start_date,
        {{ parse_date('exit_date', 'DD-MON-YY') }} as employment_exit_date,

        -- org structure
        business_unit,
        department_type,
        division,
        location_code,
        state,

        -- role
        title,
        job_function_description,
        supervisor,

        -- demographics
        {{ parse_date('dob', 'DD-MON-YY') }} as date_of_birth,
        gender_code,
        race_desc,
        marital_desc,

        -- performance
        performance_score,
        current_employee_rating,

        -- derived flags
        case
            when lower(employee_status) like '%terminate%' then 'terminated'
            when lower(employee_status) like '%active%' then 'active'
            when lower(employee_status) like '%leave%' then 'leave'
            else 'other'
        end as employee_status_group,

        case
            when exit_date is null then true
            when employee_status = 'Future Start' then false
            else false
        end as is_active_employee,

        case
            when employee_status_group = 'terminated' then 1 else 0
        end as is_terminated_employee,

        -- metadata
        current_timestamp as _loaded_at

    from source

)

select * from renamed