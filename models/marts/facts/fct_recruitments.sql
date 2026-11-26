{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='applicant_id',
        on_schema_change='sync_all_columns',
        cluster_by=['application_date']
    )
}}

-- Grain: one row per application (assuming applicant_id identifies an application).
--
-- No reliable source change timestamp exists. Instead of filtering by
-- application_date, compare a stable hash of the current source business
-- attributes with the same attributes in the existing target.
--
-- The source is scanned in full on incremental runs. Only inserts and changed
-- rows are passed to dbt's MERGE. This is incremental writing, not CDC.
--
-- HASH is a non-cryptographic 64-bit fingerprint; collisions are possible,
-- so source-to-target reconciliation remains important.

with source_applications as (

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

changed_applications as (

    select source_applications.*

    from source_applications

    {% if is_incremental() %}

        left join {{ this }} as existing
            on source_applications.applicant_id = existing.applicant_id

        where existing.applicant_id is null
            or hash(
                source_applications.application_date,
                source_applications.application_status,
                source_applications.job_title,
                source_applications.years_of_experience,
                source_applications.desired_salary,
                source_applications.hired_flag
            ) <> hash(
                existing.application_date,
                existing.application_status,
                existing.job_title,
                existing.years_of_experience,
                existing.desired_salary,
                existing.hired_flag
            )

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
        hired_flag,
        current_timestamp() as dbt_updated_at,
        'dbt_incremental_merge' as record_source

    from changed_applications

)

select * from final
