-- Grain: 1 row per source employee record

with employee as (

    select * from {{ ref('employee_snapshot') }}
    where dbt_valid_to is null

),
 
employee_enriched as (

    select
        -- primary key
        employee_id as employee_id,
        canonical_employee_id,

        -- identity
        concat(first_name, ' ', last_name) as employee_full_name,
        email as employee_email,

        -- demographics
        date_of_birth,
        gender_code,

        -- org structure
        department_type,
        business_unit,
        division,

        -- employment info
        employee_status_group,
        employment_start_date,
        employment_exit_date,
        is_active_employee,
        is_terminated_employee,

        -- counts number of employment records tied to the same canonical employee identity
        count(*) over (
            partition by canonical_employee_id
        ) as total_employment_periods

    from employee

),

final as (

    select
        *,
        -- heuristic rehire flag. Assumes multiple employee records means rehire. Often true but not always.
        case
            when total_employment_periods > 1 then true
            else false
        end as is_rehire

    from employee_enriched

)

select * from final