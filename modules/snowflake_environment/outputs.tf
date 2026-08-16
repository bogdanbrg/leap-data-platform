output "read_role" {
  description = "Access role granting read on this environment."
  value       = snowflake_account_role.read.name
}

output "transformer_role" {
  description = "Functional role dbt authenticates with in this environment."
  value       = snowflake_account_role.transformer.name
}

output "analytics_database" {
  value = snowflake_database.analytics.name
}

output "warehouse" {
  value = snowflake_warehouse.transform.name
}

output "dbt_user" {
  description = "Snowflake service user dbt authenticates as in this environment."
  value       = snowflake_service_user.dbt.name
}
