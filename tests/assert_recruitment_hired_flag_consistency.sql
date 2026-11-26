-- A data test must return zero failing rows.
-- This checks the materialized fact, not only the staging transformation.
-- "Offered" is treated as hired by the CURRENT project rule; this may not
-- be the appropriate business definition for a production recruitment KPI.

select
    applicant_id,
    application_status,
    hired_flag

from {{ ref('fct_recruitments') }}

where hired_flag is null
   or hired_flag <> case
        when application_status = 'Offered' then 1
        else 0
    end
