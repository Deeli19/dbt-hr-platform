-- SELF-CONTAINED TRAINING LAB: only CI.TRAINING_PUBLICATION_LAB is affected.
-- This script does NOT read or write the PRODUCTION database.
-- Run with a Snowflake role allowed to create schema/tables inside CI.
-- Run before 02_validate_and_promote.sql.

use database CI;
create schema if not exists CI.TRAINING_PUBLICATION_LAB;
use schema CI.TRAINING_PUBLICATION_LAB;

-- Current source state: one old application changed to Offered.
create or replace table LAB_SOURCE (
    applicant_id number,
    application_date date,
    application_status varchar,
    hired_flag number
);

insert into LAB_SOURCE values
    (1001, dateadd(day, -30, current_date()), 'Offered', 1),
    (1002, dateadd(day, -20, current_date()), 'Interviewing', 0),
    (1003, dateadd(day, -1, current_date()), 'Applied', 0);

-- Last trusted, currently published data: applicant 1001 was In Review.
create or replace table LAB_PUBLISHED (
    applicant_id number,
    application_date date,
    application_status varchar,
    hired_flag number,
    dbt_updated_at timestamp_ntz
);

insert into LAB_PUBLISHED values
    (1001, dateadd(day, -30, current_date()), 'In Review', 0, current_timestamp()),
    (1002, dateadd(day, -20, current_date()), 'Interviewing', 0, current_timestamp());

-- Zero-copy candidate snapshot: processing MUST NOT modify LAB_PUBLISHED.
create or replace table LAB_CANDIDATE clone LAB_PUBLISHED;

-- Apply changed-source state to candidate only.
merge into LAB_CANDIDATE as t
using LAB_SOURCE as s
on t.applicant_id = s.applicant_id
when matched and hash(
    t.application_date, t.application_status, t.hired_flag
) <> hash(
    s.application_date, s.application_status, s.hired_flag
) then update set
    t.application_date = s.application_date,
    t.application_status = s.application_status,
    t.hired_flag = s.hired_flag,
    t.dbt_updated_at = current_timestamp()
when not matched then insert (
    applicant_id, application_date, application_status, hired_flag, dbt_updated_at
) values (
    s.applicant_id, s.application_date, s.application_status,
    s.hired_flag, current_timestamp()
);

-- Deliberately corrupt ONLY the candidate to simulate a bug in transformations.
update LAB_CANDIDATE
set hired_flag = 0
where applicant_id = 1001;

-- Compare the unmodified published and candidate versions.
select 'published' as version, applicant_id, application_status, hired_flag
from LAB_PUBLISHED
union all
select 'candidate', applicant_id, application_status, hired_flag
from LAB_CANDIDATE
order by applicant_id, version;

-- Observe: LAB_PUBLISHED remains at the last trusted state.
