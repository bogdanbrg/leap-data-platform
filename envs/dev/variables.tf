variable "snowflake_organization_name" {
  description = "Snowflake organization name"
  type        = string
  default     = "GASKGVJ"
}

variable "snowflake_account_name" {
  description = "Snowflake account name within the organization"
  type        = string
  default     = "GF65092"
}

variable "snowflake_user" {
  description = "Service user Terraform authenticates as"
  type        = string
  default     = "SVC_TERRAFORM"
}

variable "snowflake_private_key_path" {
  description = "Path to the PKCS#8 private key. Lives outside the repo."
  type        = string
  default     = "~/.snowflake/keys/svc_terraform.p8"
}
