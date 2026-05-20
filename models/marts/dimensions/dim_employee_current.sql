-- Grain: 1 row per source employee record

with employee as (

    select * from {{ ref('employee_snapshot') }}
    where dbt_valid_to is null

),

employee_identity as (

    select *
    from {{ ref('int_employee_identity') }}

),

employee_enriched as (

    select
        -- primary key
        e.employee_id as employee_id,
        ei.canonical_employee_id,

        -- identity
        concat(e.first_name, ' ', e.last_name) as employee_full_name,
        e.email as employee_email,

        -- demographics
        e.date_of_birth,
        e.gender_code,

        -- org structure
        e.department_type,
        e.business_unit,
        e.division,

        -- employment info
        e.employee_status_group,
        e.employment_start_date,
        e.employment_exit_date,
        e.is_active_employee,
        e.is_terminated_employee

    from employee e
    inner join employee_identity ei
        on e.employee_id = ei.employee_id

),

employment_metrics as (

    select
        *,

        -- counts number of employment records tied to the same canonical employee identity
        count(*) over (
            partition by canonical_employee_id
        ) as employment_record_count,

        -- employee tenure in days
        {{calculate_tenure_days('employment_start_date', 'employment_exit_date') }} as tenure_days

    from employee_enriched

),

final as (

    select
        *,

        -- heuristic rehire flag. Assumes multiple employee records means rehire. Often true but not always.
        case
            when employment_record_count > 1 then true
            else false
        end as is_rehire

    from employment_metrics

)

select * from final