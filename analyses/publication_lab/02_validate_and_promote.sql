-- Run in Snowflake after 01_prepare_candidate.sql.
-- FIRST run the validation block below WITHOUT correcting the candidate:
-- it MUST fail, leaving LAB_PUBLISHED untouched.
-- Then fix LAB_CANDIDATE, rerun validation, and only then run the swap.
-- No real PRODUCTION objects are referenced.

use database CI;
use schema CI.TRAINING_PUBLICATION_LAB;

-- VALIDATION GATE: fail if source != candidate, candidate has duplicates,
-- or the current project status-to-hired-flag rule is broken.
execute immediate $$
declare
    violation_count number default 0;
    invalid_candidate exception (-20001,
        'Candidate validation failed: publication is blocked');
begin
    select count(*) into :violation_count
    from (
        -- Detect source records missing or different in candidate
        select s.applicant_id
        from CI.TRAINING_PUBLICATION_LAB.LAB_SOURCE s
        left join CI.TRAINING_PUBLICATION_LAB.LAB_CANDIDATE c
            on s.applicant_id = c.applicant_id
        where c.applicant_id is null
           or hash(s.application_date, s.application_status, s.hired_flag)
              <> hash(c.application_date, c.application_status, c.hired_flag)

        union all

        -- Detect unexpected extra candidate records
        select c.applicant_id
        from CI.TRAINING_PUBLICATION_LAB.LAB_CANDIDATE c
        left join CI.TRAINING_PUBLICATION_LAB.LAB_SOURCE s
            on s.applicant_id = c.applicant_id
        where s.applicant_id is null

        union all

        -- Enforce unique grain
        select applicant_id
        from CI.TRAINING_PUBLICATION_LAB.LAB_CANDIDATE
        group by applicant_id
        having count(*) <> 1

        union all

        -- Enforce this project's current business rule
        select applicant_id
        from CI.TRAINING_PUBLICATION_LAB.LAB_CANDIDATE
        where applicant_id is null
           or application_status is null
           or hired_flag is null
           or hired_flag <> case when application_status = 'Offered'
                                then 1 else 0 end
    );
    if (violation_count > 0) then
        raise invalid_candidate;
    end if;
end;
$$;

-- STOP HERE on the first run. The above block must fail.
-- Confirm LAB_PUBLISHED is unchanged before repairing candidate:
select applicant_id, application_status, hired_flag
from CI.TRAINING_PUBLICATION_LAB.LAB_PUBLISHED
order by applicant_id;

-- For the second attempt, run this repair:
-- update CI.TRAINING_PUBLICATION_LAB.LAB_CANDIDATE
-- set hired_flag = 1 where applicant_id = 1001;
--
-- Then rerun the VALIDATION GATE (execute immediate $$ ... $$) above.
-- ONLY after that block returns successfully, execute the promotion below.

-- VALIDATED PROMOTION: run this statement separately, AFTER a passing gate.
-- Atomic name swap; readers of LAB_PUBLISHED see the newly validated version.
-- Requires sufficient ownership privileges for both training tables.
-- alter table CI.TRAINING_PUBLICATION_LAB.LAB_PUBLISHED
--     swap with CI.TRAINING_PUBLICATION_LAB.LAB_CANDIDATE;

-- Verify after promotion:
-- select applicant_id, application_status, hired_flag
-- from CI.TRAINING_PUBLICATION_LAB.LAB_PUBLISHED
-- order by applicant_id;
--
-- LAB_CANDIDATE now has the previous published version after the swap.
-- In production, protect promotion against concurrent writes or source drift
-- between validation and swap. Do not treat a previous validation as a durable
-- approval if the candidate can be modified after it passes.
