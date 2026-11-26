# Engineering exercise: separate deployment from scheduled data refresh

This change intentionally leaves CI as-is. It separates **code deployment**
from **recurring source-data processing** in production, and adds a **safe
Snowflake lab** demonstrating validate-before-publish.

## Pipeline responsibilities

| Workflow | Trigger | Behavior |
| --- | --- | --- |
| `.github/workflows/dbt_ci.yml` | PR against main | Compile and build modified nodes and their descendants in CI; test them. |
| `.github/workflows/dbt_prod_deploy.yml` | Push to main or manual dispatch | Execute production dbt build on reviewed code and upload the manifest for Slim CI. |
| `.github/workflows/dbt_prod_run.yml` | Monthly or manual dispatch | Execute dbt build with main's code to process source changes and run data tests; save run diagnostics. |

**Cadence:** Original monthly schedule is retained in the *scheduled run*
workflow. Agree on business freshness SLAs before changing to daily/hourly.

**Execution warning:** This is a learning environment. Production deployment
still uses `dbt build` to materialize changes because dbt Core is a
transformation framework, not a binary deployment system. Every run may
recompute tables and cost Snowflake credits. The workflow does not isolate
production writes behind a candidate publication gate.

**Serialization:** Both production workflows share the same GitHub Actions
concurrency group and do not cancel running jobs. This helps avoid concurrent
workflow writes, but is not a cross-system lock for dbt jobs run by other
orchestrators or users.

**Manifest:** Slim CI downloads the `manifest-artifact` from
`dbt_prod_deploy.yml`. This remains available following a successful
deployment. A failed deploy has no new success artifact. Note that normal
pull-request Slim CI does *not* detect source-only changes; recurring
processing and production tests are responsible for those.

**Important operational limitations to discuss in interview:**
- A GitHub Actions `push` workflow runs after merging code, not before; require
  PR checks/review rules for merge safety. These are not configured by this PR.
- Merging a change triggers a production build, not just copying artifacts.
- The scheduled job follows the approved main branch, but a PR must not be
  treated as deployed until its production job finishes successfully.
- Consider production environment approvals, least-privilege service roles,
  notifications, test gating, deployment recovery, and dbt model ownership.
- Review the job/warehouse timeouts against actual warehouse workload.
- Model-level tests usually run *after* materialization; a failed dbt test
  does not automatically roll back previously committed model changes.
- Current project includes archive-day-dependent models; the date-sensitive
  data output needs its own cadence and test strategy if run frequency changes.

## Candidate publication lab

Scripts:
1. `analyses/publication_lab/01_prepare_candidate.sql`
2. `analyses/publication_lab/02_validate_and_promote.sql`

The lab **only targets `CI.TRAINING_PUBLICATION_LAB`**. You need appropriate
privileges to create the schema and tables within your CI database. It does
not update your HR project marts or any `PRODUCTION` object.

### Failure scenario

Run the first script in a Snowflake worksheet. It sets up a source application
from 30 days ago, an old trusted published state, and a candidate zero-copy
clone. The source-to-candidate merge updates the old application and adds a new
application, then *deliberately* corrupts the candidate's `hired_flag`.

In the second script, **run just the validation gate**. It must raise a custom
exception. Verify that `LAB_PUBLISHED` has not been modified.

### Successful promotion

Repair the candidate with the UPDATE documented in the second script, then
rerun the entire validation gate. If it passes, execute the commented
`ALTER TABLE ... SWAP WITH ...` separately and confirm the published data
now has the new status and the newly inserted application.

Unlike an in-place merge followed by a dbt test, this pattern prevents
unvalidated candidate rows from becoming visible in the published relation.
The table swap is atomic from readers' perspective.

### What this lab does NOT implement

- A full dbt materialization/custom schema orchestration for every model
- Production isolation/validation of an entire dependency graph
- Automated gating and swap in a single orchestrated transaction/process
- External consumer permission changes, security controls or operational alerts
- A concurrency-safe publication lock, snapshot consistency guarantee, or
  rollbacks of already consumed external reports

Promoting an entire data product with multiple related tables requires more
than individually swapping tables; consider validated versioned schemas/views,
coordinated cutover, reproducible snapshots, and dependency consistency.

### Interview summary

> We distinguish code promotion, scheduled data refresh, and validated data
> publication. CI checks code and selected models before merge; a separate
> scheduled job processes source changes with approved code. For critical
> tables, process changes into a candidate, validate the complete new state,
> and expose that version only after validation succeeds.
