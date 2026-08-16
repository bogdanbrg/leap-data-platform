# Data Platform Architecture

Design for the LEAP case. High level, no code — the Terraform in this repo is the
implementation of the decisions below.

---

## 1. The organising principle

> **Terraform owns the containers. dbt owns the contents.**

Terraform manages databases, schemas, warehouses, roles and **future grants** — the
slow-changing, high-blast-radius scaffolding. dbt creates tables and views at runtime
inside that scaffolding. The two never fight over the same object.

This single rule resolves the question that otherwise causes chaos: *who grants
permissions on a table dbt created five minutes ago?* Answer: nobody grants it
individually. Terraform declares, once, that anything appearing in this schema is
readable by this role. dbt then creates freely.

```
                    ┌─────────────────────────────────────────┐
   Terraform ──────▶│  databases · schemas · warehouses        │
   (control plane)  │  roles · grants · FUTURE grants          │
                    └─────────────────────────────────────────┘
                                      │ containers exist
                                      ▼
                    ┌─────────────────────────────────────────┐
   dbt ────────────▶│  tables · views · tests · docs · lineage │
   (transformation) └─────────────────────────────────────────┘
                                      │
   Git + CI/CD ──── gates every change to both ────────────────
```

---

## 2. Environment separation

**Decision: database-per-environment, in a single Snowflake account.**

| Option | Verdict |
|---|---|
| Schema-per-environment | Rejected — weak isolation, dev and prod objects interleaved in one namespace, awkward grants |
| **Database-per-environment** | **Chosen** — clean blast-radius boundary, maps directly onto dbt targets, one account to administer |
| Account-per-environment | The enterprise endgame. Strongest isolation, separate billing and account-level config. Rejected for scope: more admin than a 4-day case justifies |

Separate Terraform **state per environment** (`envs/dev`, `envs/prod`) so a broken dev
apply can never touch prod.

**What we give up** by not going account-per-environment: account-level objects —
network policies, resource monitors, authentication policies — are shared between dev
and prod. In a regulated client I would split accounts under one organisation and
accept the extra administration.

---

## 3. Databases and schemas

```
RAW_DEV                     RAW_PROD
  └─ (landing zone)           └─ (landing zone)
     EL writes here              EL writes here
     dbt only READS              dbt only READS

ANALYTICS_DEV               ANALYTICS_PROD
  └─ per-developer schemas     ├─ STAGING       1:1 with sources, renamed/retyped. Views.
     DBT_BOGDAN_STAGING        ├─ INTERMEDIATE  business logic in readable steps.
     DBT_BOGDAN_MARTS          └─ MARTS         dimensional model. Tables.
     (created by dbt)             (created by Terraform)
```

**RAW is created but empty**, and that is deliberate. The case scopes out ingestion, so
there is no EL tool landing data. The demo reads from `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1`
instead. `RAW_*` exists to show where a Fivetran / Airbyte / Snowpipe layer would write,
and to make the "dbt never writes to RAW" boundary explicit in code rather than in
conversation.

**Why developers get their own schema in dev.** `DBT_BOGDAN_*` is dbt's default
behaviour and it means two people can build the same model simultaneously without
collision. Terraform does not create these — dbt does, at runtime. Terraform's job is
the future grants that make them readable.

**Managed access on production schemas.** `WITH MANAGED ACCESS` means only the schema
owner can issue grants, not individual object owners. It stops grant sprawl: permissions
stay centralised in Terraform instead of accumulating wherever somebody had ownership.

---

## 4. Role model

**Decision: two-tier — access roles hold privileges, functional roles are granted to users.**

```
                    ┌──────────────┐
                    │   SYSADMIN   │  ← all custom roles roll up here
                    └──────┬───────┘
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
   FR_TRANSFORMER_DEV  FR_TRANSFORMER_PROD  FR_ANALYST     ← functional (granted to users)
          │                │                │
   ┌──────┴──────┐  ┌──────┴──────┐  ┌──────┴──────┐
   ▼             ▼  ▼             ▼  ▼             ▼
 AR_RAW_DEV_R  AR_ANALYTICS_DEV_W  AR_ANALYTICS_PROD_R ...  ← access (hold the grants)
          │                │                │
          ▼                ▼                ▼
      databases · schemas · warehouses
```

**Access roles** — one per object-and-privilege. These are the *only* roles that hold
grants on objects:

| Role | Grants |
|---|---|
| `AR_RAW_<ENV>_READ` | USAGE on database + schemas, SELECT on all & future tables/views |
| `AR_ANALYTICS_<ENV>_READ` | as above, on ANALYTICS |
| `AR_ANALYTICS_<ENV>_WRITE` | READ plus CREATE SCHEMA / TABLE / VIEW |
| `AR_WH_<NAME>_USAGE` | USAGE on one warehouse |

**Functional roles** — one per job someone does. Granted access roles; never granted
privileges directly:

| Role | Composed of | Who uses it |
|---|---|---|
| `FR_TRANSFORMER_DEV` | RAW_DEV read, ANALYTICS_DEV write, WH_TRANSFORM_DEV usage | dbt dev + CI |
| `FR_TRANSFORMER_PROD` | RAW_PROD read, ANALYTICS_PROD write, WH_TRANSFORM_PROD usage | dbt production jobs |
| `FR_ANALYST` | ANALYTICS_PROD read, WH_BI usage | BI tools, analysts |
| `FR_LOADER_<ENV>` | RAW_<ENV> write, WH_LOADING usage | the EL tool (declared, currently unused) |

**Three rules, and the reason for each:**

1. **Users are granted functional roles only.** Someone changes team → swap one role.
2. **Privileges are granted to access roles only.** A new database appears → create one
   access role and attach it, instead of editing every user.
3. **All custom roles roll up to `SYSADMIN`.** So `SYSADMIN` can administer everything
   without anyone needing `ACCOUNTADMIN` day to day.

The indirection is the entire point. It converts an O(users × objects) permission
problem into two O(n) problems.

**Ownership matters as much as privilege.** In Snowflake the owning role can do anything
to an object regardless of grants. Objects are owned by the access role that created
them, and managed-access schemas prevent owners from re-granting.

---

## 5. Warehouses (compute)

Snowflake separates storage from compute, so independent clusters can run over the same
data. That makes **one warehouse per workload** the correct default — it isolates
contention and makes cost attributable.

| Warehouse | Size | Scope | Purpose |
|---|---|---|---|
| `WH_TRANSFORM_DEV` | XS | per-env | dbt in development and CI |
| `WH_TRANSFORM_PROD` | XS | per-env | dbt production jobs |
| `WH_BI` | XS | account | analysts and BI tools, read-only |

All three: `AUTO_SUSPEND = 60`, `AUTO_RESUME = TRUE`, `INITIALLY_SUSPENDED = TRUE`.

**Why those settings are not decoration.** Snowflake bills per second with a 60-second
minimum. A warehouse left running costs money continuously whether or not anyone
queries it. Auto-suspend at 60 seconds is the single highest-leverage cost control in
the platform.

**Sizing philosophy:** size *up* (a bigger warehouse) for a single slow query; scale
*out* (multi-cluster, Enterprise edition) for many concurrent queries. These solve
different problems and are commonly confused. Everything starts at XS and is raised only
with evidence from `QUERY_HISTORY`.

**Deliberately deferred:** resource monitors with credit quotas. They require
`ACCOUNTADMIN`, and `SVC_TERRAFORM` intentionally holds only `SYSADMIN` +
`SECURITYADMIN`. Rather than escalate the service account across the board, this is
documented as a narrow exception — the production answer is a separate, tightly-scoped
privilege grant rather than a blanket upgrade.

**Cost attribution:** dbt sets `QUERY_TAG` on every session, so `QUERY_HISTORY` can
attribute credits down to the individual model and job.

---

## 6. Naming conventions

```
AR_<DOMAIN>_<ENV>_<PRIVILEGE>     AR_ANALYTICS_PROD_WRITE
FR_<FUNCTION>_<ENV>               FR_TRANSFORMER_PROD
WH_<WORKLOAD>_<ENV>               WH_TRANSFORM_DEV
<DOMAIN>_<ENV>                    ANALYTICS_PROD
SVC_<PURPOSE>                     SVC_TERRAFORM
```

Prefixes make role type visible at a glance in `SHOW GRANTS` output, which is where you
actually debug permissions. Environment always last but one, so sorting groups related
objects.

---

## 7. Identities

| Identity | Type | Auth | Roles |
|---|---|---|---|
| `BOGDANBIRGOVAN` | PERSON | password + MFA | ACCOUNTADMIN (break-glass only) |
| `SVC_TERRAFORM` | SERVICE | key-pair | SYSADMIN, SECURITYADMIN |
| `SVC_DBT` | SERVICE | key-pair | FR_TRANSFORMER_DEV, FR_TRANSFORMER_PROD |

`TYPE = SERVICE` means those users *cannot* authenticate with a password — Snowflake
refuses it structurally, rather than relying on policy.

**Known simplification:** one `SVC_DBT` user holding both transformer roles, with each
dbt Cloud environment selecting the appropriate role. Separate `SVC_DBT_DEV` and
`SVC_DBT_PROD` users would be stronger — a compromised dev credential could not reach
production at all — at the cost of a second key pair to manage. Documented as a
deliberate scope decision, not an oversight.

**Human access in production** would be SSO (SAML) with SCIM provisioning, so joiners
and leavers flow from the identity provider rather than being managed in Snowflake.
Out of scope for a trial account.

---

## 8. Where each environment lives end to end

| | Dev | CI | Prod |
|---|---|---|---|
| Database | `ANALYTICS_DEV` | `ANALYTICS_DEV` | `ANALYTICS_PROD` |
| Schema | `DBT_<DEVELOPER>_*` | `DBT_CLOUD_PR_*` (ephemeral) | `STAGING` / `INTERMEDIATE` / `MARTS` |
| Warehouse | `WH_TRANSFORM_DEV` | `WH_TRANSFORM_DEV` | `WH_TRANSFORM_PROD` |
| Snowflake role | `FR_TRANSFORMER_DEV` | `FR_TRANSFORMER_DEV` | `FR_TRANSFORMER_PROD` |
| dbt environment | Development | CI (deployment) | Production (deployment) |
| Terraform state | `envs/dev` | — | `envs/prod` |

CI schemas are created per pull request and dropped when it closes, so review builds
never accumulate.

---

## 9. What "scalable" looks like in the code

The case asks for *minimum required resources to demonstrate understanding of building
scalable infrastructure*. The proof is not volume — it is that one module is
instantiated over a map:

```
module "environment" {
  source   = "../../modules/snowflake_environment"
  for_each = var.environments        # { dev = {...}, prod = {...} }
  ...
}
```

Adding `staging` is a three-line change to a variable, not a copy-paste of every
resource. That single pattern is the argument.

---

## 10. Deliberately out of scope

| Not built | Why | What it would be |
|---|---|---|
| Ingestion / EL | Case scopes it out; no source system provided | Fivetran or Snowpipe landing into `RAW_*` |
| Resource monitors | Require `ACCOUNTADMIN`; service account is deliberately narrower | Credit quotas with notify + suspend triggers |
| SSO / SCIM | Not available on a trial | SAML + automated provisioning for all human users |
| Masking / row access policies | Enterprise features, no sensitive data to protect here | Tag-based masking on PII columns |
| Account-per-environment | Administration cost exceeds a 4-day case | Separate accounts under one organisation |
| Zero-copy-clone CI environments | Time | `CREATE DATABASE ... CLONE` per PR, dropped on close |
