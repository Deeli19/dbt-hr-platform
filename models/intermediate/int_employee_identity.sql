-- Grain: 1 row per source employee record

-- Purpose:
-- Enrich employee records with canonical identity attributes

with employee as (

    select *

    from {{ ref('stg_hr__employee') }}

),

identity_resolution as (

    select

        employee_id,

        email,

        first_name,
        last_name,

        min(employee_id) over (
            partition by lower(email)
        ) as canonical_employee_id

    from employee

)

select *

from identity_resolution