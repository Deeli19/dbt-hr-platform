# Engineering exercise: controlled dbt releases and scheduled processing

This PR separates CI, release deployment, and recurring data processing.
It also provides a separate **CI-database candidate publication lab**.

## Pipeline responsibilities

| Workflow | Trigger | Responsibility |
| --- | --- | --- |
| `.github/workflows/dbt_ci.yml` | PR against main | Compare code with last successful production manifest; build changed models and descendants in CI; run selected tests. |
| `.github/workflows/dbt_prod_deploy.yml` | Manual workflow dispatch only | Release an exact, reviewed commit reachable from main; bootstrap or selectively build affected models; publish manifest; advance production-release ref on success. |
| `.github/workflows/dbt_prod_run.yml` | Monthly or manual | Resolve production-release to the last successfully deployed SHA and run dbt build using *that exact code*, regardless of newer commits to main. |

**Important:** A merge to `main` does not trigger a production dbt build.
The original monthly schedule is retained for production processing. Choose a
different frequency only after establishing a data-freshness requirement.

## Initial release bootstrap — REQUIRED before scheduled processing

The scheduled workflow intentionally fails closed if there is no
`production-release` ref. Once this PR is merged and reviewed:

1. Choose the exact 40-character commit SHA on main you intend to release
   (for example, `git rev-parse origin/main` in your local clone).
2. In GitHub Actions, manually run **dbt Production Release** from `main`.
3. Enter that exact `release_sha`. Set `full_build=true` for the first release.
4. The job verifies the SHA is reachable from main, checks out that exact
   commit, and runs a full production `dbt build`.
5. After build success it uploads `manifest-artifact`, containing
   `manifest.json` and `deployed_sha.txt`, and moves or creates
   `refs/heads/production-release` pointing to the successfully built SHA.
6. Only then can the scheduled workflow resolve and run the deployed revision.

**Operational prerequisites:** The GitHub Actions token needs permission to
create/update the `production-release` branch; repository branch rules may
restrict it. The deployment job references GitHub environment
`production-release`; **configure required reviewers** in GitHub Settings
before production use. The workflow definition alone does not enforce human
approval unless environment protection is configured.

## Subsequent releases — state-based selective production build

1. Five engineers can merge reviewed PRs to main without triggering production.
2. A release owner selects a specific 40-character commit already on main.
3. The deployment fetches the latest successful manifest artifact **from the
   production release workflow**, not from CI or a scheduled data run.
4. The deployed revision marker in the downloaded artifact must match the
   current `production-release` ref. If it is missing or stale, the
   selective build fails closed. Use an explicitly approved full build if
   recovery from missing state is required.
5. The default release command is:

   ```bash
   dbt build --target prod --select state:modified+ --state state/
   ```

   This compares released dbt definitions with the previous successful
   production manifest, and includes downstream dependencies and their
   selected tests. Nonmodel resources, migrations, changed grants, snapshots,
   or global configuration may require a broader or explicitly full run.
6. After a successful build, the workflow uploads the new manifest and
   updates the `production-release` ref. Scheduled runs always fetch that ref
   and check out its exact commit SHA.

The release ref is **forward-only** relative to the previously deployed
commit. For a rollback, create and approve a new revert commit and release it;
don't force-move the ref backward.

### How this controls costs and team collaboration

- Five merges do not create five full production builds.
- A single release can bundle multiple approved changes, with affected-model
  selection limiting unnecessary rebuilds.
- Scheduled data updates execute a fixed, already released code revision,
  not the moving `main` branch.
- Both production workflows share a GitHub concurrency group with
  `cancel-in-progress: false`. GitHub concurrency does not provide a durable
  FIFO queue and may replace older pending runs. It does not coordinate
  external orchestrators.

### Caveats and further production hardening

- A `dbt build` may materialize and commit an invalid model before a test
  fails. This PR does NOT put production dbt output behind the candidate
  publication gate in the lab.
- GitHub Actions execution and an artifact upload are not atomic with a Git
  ref update. If the build succeeds but advancing the ref fails, investigate
  the partially materialized production state before retrying.
- Artifact retention is 90 days. A stale or expired artifact requires an
  explicitly approved full-build recovery; a persistent object-storage
  manifest plus deployed revision metadata is preferable for long-lived
  production environments.
- A selective build only checks nodes selected by dbt's state selector.
  Assess changed macros, indirect test selection, snapshots, seed updates,
  schema migrations, contracts and global configuration during release
  review. A full build may be appropriate for some changes.
- Reviewers should configure branch protection / required CI, least-privilege
  Snowflake roles, GitHub environment approvers, alerting and release
  auditability. These controls are not all configured by this PR.
- The scheduled job currently runs `dbt build --target prod`, which builds all
  project resources and may be costlier than an intentionally scoped
  processing DAG. This is a separate performance improvement.
- The current HR project includes archive-day-sensitive models; the monthly
  cadence and source freshness requirements must be reviewed independently.

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
