terraform {
  required_providers {
    snowflake = {
      source                = "snowflakedb/snowflake"
      version               = "~> 2.19"
      configuration_aliases = [snowflake.sysadmin, snowflake.securityadmin]
    }
  }
}

locals {
  env = upper(var.environment)
}

########################################
# Databases
########################################

# Landing zone. An EL tool would write here; dbt only ever reads.
# Empty in this build because ingestion is out of scope for the case.
resource "snowflake_database" "raw" {
  provider                    = snowflake.sysadmin
  name                        = "RAW_${local.env}"
  data_retention_time_in_days = var.data_retention_days
  comment                     = "Landing zone for ${local.env}. Written by EL, read-only to dbt."
}

# dbt's output lives here.
resource "snowflake_database" "analytics" {
  provider                    = snowflake.sysadmin
  name                        = "ANALYTICS_${local.env}"
  data_retention_time_in_days = var.data_retention_days
  comment                     = "Transformed data for ${local.env}. Written by dbt."
}

# Managed access: only the schema owner can grant, which keeps
# permissions centralised in Terraform instead of sprawling.
resource "snowflake_schema" "analytics" {
  provider            = snowflake.sysadmin
  for_each            = toset(var.analytics_schemas)
  database            = snowflake_database.analytics.name
  name                = each.value
  with_managed_access = "true"
}

########################################
# Compute
########################################

resource "snowflake_warehouse" "transform" {
  provider            = snowflake.sysadmin
  name                = "WH_TRANSFORM_${local.env}"
  warehouse_size      = var.warehouse_size
  auto_suspend        = 60
  auto_resume         = "true"
  initially_suspended = true
  comment             = "dbt transformations for ${local.env}."
}

########################################
# Roles: access roles hold privileges
########################################

resource "snowflake_account_role" "read" {
  provider = snowflake.securityadmin
  name     = "AR_${local.env}_READ"
  comment  = "Access role: read ${local.env} data."
}

resource "snowflake_account_role" "write" {
  provider = snowflake.securityadmin
  name     = "AR_${local.env}_WRITE"
  comment  = "Access role: create and modify objects in ANALYTICS_${local.env}."
}

########################################
# Roles: functional roles are what users get
########################################

resource "snowflake_account_role" "transformer" {
  provider = snowflake.securityadmin
  name     = "FR_TRANSFORMER_${local.env}"
  comment  = "Functional role for dbt in ${local.env}."
}
