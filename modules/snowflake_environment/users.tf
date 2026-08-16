locals {
  # Snowflake wants the base64 body on a single line, so strip the PEM
  # header, footer and newlines.
  dbt_public_key = replace(
    replace(
      replace(file(pathexpand(var.dbt_public_key_path)), "-----BEGIN PUBLIC KEY-----", ""),
      "-----END PUBLIC KEY-----", ""),
    "\n", "")
}

# One dbt identity per environment. Separate keys mean a compromised dev
# credential cannot reach production.
resource "snowflake_service_user" "dbt" {
  provider          = snowflake.securityadmin
  name              = "SVC_DBT_${local.env}"
  rsa_public_key    = local.dbt_public_key
  default_role      = snowflake_account_role.transformer.name
  default_warehouse = snowflake_warehouse.transform.name
  comment           = "dbt service identity for ${local.env}. Managed by Terraform."
}

resource "snowflake_grant_account_role" "dbt_user" {
  provider  = snowflake.securityadmin
  role_name = snowflake_account_role.transformer.name
  user_name = snowflake_service_user.dbt.name
}
