module "environment" {
  source = "../../modules/snowflake_environment"

  providers = {
    snowflake.sysadmin      = snowflake.sysadmin
    snowflake.securityadmin = snowflake.securityadmin
  }

  environment         = "dev"
  warehouse_size      = "XSMALL"
  data_retention_days = 1
}

output "transformer_role" {
  value = module.environment.transformer_role
}

output "analytics_database" {
  value = module.environment.analytics_database
}

output "warehouse" {
  value = module.environment.warehouse
}
