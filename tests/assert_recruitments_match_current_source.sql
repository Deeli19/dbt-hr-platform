-- Detect missing or stale applications, including changes to old applications.
-- This deliberately ignores extra target rows (source deletions are not yet
-- supported); deletion handling needs an explicit business policy.
-- Source applicant_id uniqueness is separately tested.

with source_rows as (

    select
        applicant_id,
        application_date,
        application_status,
        job_title,
        years_of_experience,
        desired_salary,
        hired_flag
    from {{ ref('stg_hr__recruitments') }}

),

target_rows as (

    select
        applicant_id,
        application_date,
        application_status,
        job_title,
        years_of_experience,
        desired_salary,
        hired_flag
    from {{ ref('fct_recruitments') }}

)

select
    s.applicant_id,
    case
        when t.applicant_id is null then 'missing_in_target'
        else 'business_values_differ'
    end as discrepancy

from source_rows s

left join target_rows t
    on s.applicant_id = t.applicant_id

where t.applicant_id is null
    or hash(
        s.application_date,
        s.application_status,
        s.job_title,
        s.years_of_experience,
        s.desired_salary,
        s.hired_flag
    ) <> hash(
        t.application_date,
        t.application_status,
        t.job_title,
        t.years_of_experience,
        t.desired_salary,
        t.hired_flag
    )
