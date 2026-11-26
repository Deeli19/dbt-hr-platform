# Recruitment incremental processing: hash comparison versus CDC

## Business requirement

Applications can change status long after their original application_date.
A filter on the most recent application_date therefore misses updates to old
applications. The source lacks an authoritative last_modified_at or CDC feed.

## Current solution: source-to-target hash comparison

Model: `models/marts/facts/fct_recruitments.sql`.

1. Read the current source state of each application.
2. On incremental runs, left join source to the existing fact using applicant_id.
3. Compute identical Snowflake HASH fingerprints over stable business attributes
   on each side (application_date, application_status, job_title,
   years_of_experience, desired_salary, hired_flag).
4. Send only new IDs and changed fingerprints to dbt's incremental MERGE.
5. Preserve unchanged destination rows and their dbt_updated_at value.
6. Run key, business-rule, and full source-to-target reconciliation data tests.

The target's column layout remains unchanged: hashes are calculated transiently
on source and target, so a new persistent row_hash column is not required.

### Constraints

- The source must provide one current row per application. The project's
  applicant_id must identify an *application*, not merely an individual.
- Reads still scan the whole current source and join to the target. This is
  incremental *writing* and NOT change data capture. Evaluate cost and runtime.
- HASH is a Snowflake non-cryptographic 64-bit fingerprint; collisions are
  possible. For strict correctness, compare values null-safely using
  `IS DISTINCT FROM` or consider a well-defined SHA2 fingerprint policy.
- Source deletes are not propagated; the source-to-target test deliberately
  ignores extra target rows. Define soft-delete / hard-delete policy separately.
- An intermediate sequence of changes between polls may be invisible. The
  latest surviving source state is all the model can observe.
- Concurrent source updates during the source scan can lead to inconsistent
  comparisons; consider consistent snapshots, isolation and reconciliation.
- This is a Type 1 current-state model; it does NOT keep a status history.
  Use an event log/CDC or snapshot mechanism if history is required.
- Materialized target updates are not proof of an integration test involving a
  source status change. Reproduce this scenario in a controlled environment.

## Safe validation exercise

Use a development/CI dataset, not the shared production source:

1. Create a fixture application with an application_date 30+ days old,
   status 'In Review', and a stable applicant_id.
2. Build the target once and record applicant_id, status, hired_flag,
   dbt_updated_at and count.
3. Change only the source status to 'Offered'; application_date remains old.
4. Run `dbt build --select +fct_recruitments` against the isolated target.
5. Verify one target row exists, status='Offered', hired_flag=1, and source
   reconciliation tests pass.
6. Rerun with no source changes. Confirm the business values and dbt_updated_at
   for the unchanged application do not change.
7. Change a non-status business attribute (e.g. job_title); confirm it updates.
8. Test source duplicate applicant_id and confirm a data test fails.

Do not merge merely because CI builds succeeded; exercise the update path as well.

## How genuine CDC would work

True CDC captures INSERT, UPDATE and DELETE operations and their order rather
than repeatedly scanning a full current-state table.

### Pattern A: upstream database log-based CDC

`source OLTP transaction log -> Debezium / managed CDC -> Kafka or object storage -> Snowflake landing change log -> dedupe/order -> current-state MERGE -> dbt marts`

- A database's transaction log exposes mutations and position metadata
  (LSN / commit sequence, transaction ID, operation, source commit time).
- Connector software ingests and publishes the changes. Initial backfill is
  reconciled with the log position to avoid missing/duplicating events.
- Land immutable change records including stable application key, operation
  type, commit order, and source metadata.
- Before merging, choose the latest committed event for each business key in
  the consumed batch. Updates and deletes require explicit handling.
- Track durable ingestion/consumption offsets and retry/idempotency behavior.
- dbt can transform the resulting current-state landing table or event log.

### Pattern B: Snowflake Streams + Tasks

If an upstream ingestion pipeline *already mutates a Snowflake table* (INSERT,
UPDATE, DELETE, or MERGE), a Snowflake stream tracks table-level changes since
the stream offset. A scheduled task can consume those changes into a change-log
or current-state table.

Example skeleton (adapt names, permissions, and schedule before use):

```sql
create stream if not exists raw.hr.recruitment_stream
  on table raw.hr.recruitment;

-- Example inspection; querying does not advance the stream offset.
select metadata$action, metadata$isupdate, metadata$row_id, applicant_id
from raw.hr.recruitment_stream;
```

A standard stream represents an UPDATE as a DELETE/INSERT pair with
METADATA$ISUPDATE=true. MERGE consumers must account for that representation;
they should not blindly apply both as separate final states. Stream offsets
advance upon successful committed DML consumption, not a read-only SELECT.
Transaction boundaries are important for consistent processing.

Snowflake Streams track mutations **within Snowflake**; they cannot detect
changes in an external system that simply aren't ingested into Snowflake.
If a landing table is fully overwritten or recreated, investigate stream
staleness and unsupported operational patterns before relying on its offsets.

A task can execute a stored procedure or SQL MERGE and use SYSTEM$STREAM_HAS_DATA
for conditional execution. Stream retention, staleness, task errors, security,
and backfill/replay strategy are operational design decisions.

## Interview comparison

**Hash-based state comparison:** no upstream modification metadata required;
simpler, but scans the current source and may miss transient updates/deletes.

**True CDC:** capture actual mutations from logs or warehouse table changes;
better for large changing datasets and auditability but requires connector or
stream operations, ordered delivery, offset management and recovery design.

The right choice depends on availability of source mutation metadata, volume,
latency SLAs, cost, and whether the consumer needs full event history.
