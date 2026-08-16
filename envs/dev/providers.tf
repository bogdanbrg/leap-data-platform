# Two providers, one per Snowflake role. Each resource is created by the
# narrowest role that can create it, rather than everything running as
# ACCOUNTADMIN.

provider "snowflake" {
  alias             = "sysadmin"
  organization_name = var.snowflake_organization_name
  account_name      = var.snowflake_account_name
  user              = var.snowflake_user
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(pathexpand(var.snowflake_private_key_path))
  role              = "SYSADMIN"
}

provider "snowflake" {
  alias             = "securityadmin"
  organization_name = var.snowflake_organization_name
  account_name      = var.snowflake_account_name
  user              = var.snowflake_user
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(pathexpand(var.snowflake_private_key_path))
  role              = "SECURITYADMIN"
}
