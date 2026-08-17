module "environment" {
  source = "../../modules/snowflake_environment"

  providers = {
    snowflake.sysadmin      = snowflake.sysadmin
    snowflake.securityadmin = snowflake.securityadmin
  }

  environment         = "prod"
  dbt_public_key_path = "~/.snowflake/keys/svc_dbt_prod.pub"
  warehouse_size      = "XSMALL"
  data_retention_days = 7
}

########################################
# Account-level: shared across environments, so not in the module
########################################

resource "snowflake_warehouse" "bi" {
  provider            = snowflake.sysadmin
  name                = "WH_BI"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = "true"
  initially_suspended = true
  comment             = "BI and ad-hoc analyst queries. Read-only workload."
}

resource "snowflake_account_role" "analyst" {
  provider = snowflake.securityadmin
  name     = "FR_ANALYST"
  comment  = "Functional role for analysts and BI tools."
}

resource "snowflake_grant_account_role" "analyst_reads_prod" {
  provider         = snowflake.securityadmin
  role_name        = module.environment.read_role
  parent_role_name = snowflake_account_role.analyst.name
}

resource "snowflake_grant_privileges_to_account_role" "analyst_warehouse" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.bi.name
  }
}

resource "snowflake_grant_account_role" "analyst_to_sysadmin" {
  provider         = snowflake.securityadmin
  role_name        = snowflake_account_role.analyst.name
  parent_role_name = "SYSADMIN"
}

output "transformer_role" {
  value = module.environment.transformer_role
}

output "analyst_role" {
  value = snowflake_account_role.analyst.name
}

output "analytics_database" {
  value = module.environment.analytics_database
}

output "warehouse" {
  value = module.environment.warehouse
}

output "dbt_user" {
  value = module.environment.dbt_user
}

resource "snowflake_grant_account_role" "ci_reads_prod" {
  provider         = snowflake.securityadmin
  role_name        = module.environment.read_role
  parent_role_name = data.terraform_remote_state.dev.outputs.transformer_role
}
