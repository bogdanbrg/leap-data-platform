resource "dbtcloud_project" "leap" {
  name                     = "LEAP Analytics"
  dbt_project_subdirectory = "dbt"
}

# One connection to the Snowflake account. Role and database are set
# per environment by the credentials below, not here.
resource "dbtcloud_global_connection" "snowflake" {
  name = "Snowflake"

  snowflake = {
    account   = local.snowflake_account
    database  = local.prod.analytics_database
    warehouse = local.prod.warehouse
  }
}

########################################
# Credentials: one identity per environment
########################################

resource "dbtcloud_snowflake_credential" "dev" {
  project_id             = dbtcloud_project.leap.id
  auth_type              = "keypair"
  user                   = local.dev.dbt_user
  private_key_wo         = file(pathexpand("~/.snowflake/keys/svc_dbt_dev.p8"))
  private_key_wo_version = 1
  role                   = local.dev.transformer_role
  database               = local.dev.analytics_database
  warehouse              = local.dev.warehouse
  schema                 = "DBT_BOGDAN"
  num_threads            = 4
}

resource "dbtcloud_snowflake_credential" "prod" {
  project_id             = dbtcloud_project.leap.id
  auth_type              = "keypair"
  user                   = local.prod.dbt_user
  private_key_wo         = file(pathexpand("~/.snowflake/keys/svc_dbt_prod.p8"))
  private_key_wo_version = 1
  role                   = local.prod.transformer_role
  database               = local.prod.analytics_database
  warehouse              = local.prod.warehouse
  schema                 = "MARTS"
  num_threads            = 4
}

########################################
# Environments
########################################

resource "dbtcloud_environment" "dev" {
  project_id    = dbtcloud_project.leap.id
  name          = "Development"
  type          = "development"
  dbt_version   = "latest"
  connection_id = dbtcloud_global_connection.snowflake.id
  credential_id = dbtcloud_snowflake_credential.dev.credential_id
}

# CI builds into the dev database using ephemeral per-PR schemas.
resource "dbtcloud_environment" "ci" {
  project_id    = dbtcloud_project.leap.id
  name          = "CI"
  type          = "deployment"
  dbt_version   = "latest"
  connection_id = dbtcloud_global_connection.snowflake.id
  credential_id = dbtcloud_snowflake_credential.dev.credential_id
}

resource "dbtcloud_environment" "prod" {
  project_id      = dbtcloud_project.leap.id
  name            = "Production"
  type            = "deployment"
  deployment_type = "production"
  dbt_version     = "latest"
  connection_id   = dbtcloud_global_connection.snowflake.id
  credential_id   = dbtcloud_snowflake_credential.prod.credential_id
}

########################################
# Jobs
########################################

resource "dbtcloud_job" "production" {
  project_id     = dbtcloud_project.leap.id
  environment_id = dbtcloud_environment.prod.environment_id
  name           = "Production build"
  target_name    = "prod"
  execute_steps  = ["dbt build"]
  num_threads    = 4

  triggers = {
    github_webhook       = false
    git_provider_webhook = false
    schedule             = true
    on_merge             = false
  }

  schedule_type  = "days_of_week"
  schedule_days  = [1, 2, 3, 4, 5]
  schedule_hours = [5]
}

# Slim CI: build only what changed, defer everything else to production.
resource "dbtcloud_job" "ci" {
  project_id               = dbtcloud_project.leap.id
  environment_id           = dbtcloud_environment.ci.environment_id
  name                     = "CI check"
  execute_steps            = ["dbt build --select state:modified+ --fail-fast"]
  num_threads              = 4
  deferring_environment_id = dbtcloud_environment.prod.environment_id

  triggers = {
    github_webhook       = true
    git_provider_webhook = true
    schedule             = false
    on_merge             = false
  }
}

########################################
# Repository link
########################################

resource "dbtcloud_repository" "leap" {
  project_id         = dbtcloud_project.leap.id
  remote_url         = "git@github.com:bogdanbrg/leap-data-platform.git"
  git_clone_strategy = "deploy_key"
}

resource "dbtcloud_project_repository" "leap" {
  project_id    = dbtcloud_project.leap.id
  repository_id = dbtcloud_repository.leap.repository_id
}

output "deploy_key" {
  description = "Register this with the GitHub repo so dbt Cloud can clone it."
  value       = dbtcloud_repository.leap.deploy_key
}
