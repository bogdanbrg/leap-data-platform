variable "environment" {
  description = "Environment name, e.g. dev or prod. Used as a suffix on every object."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+$", var.environment))
    error_message = "Environment must be lowercase letters only."
  }
}

variable "warehouse_size" {
  description = "Snowflake warehouse size. Start XSMALL and raise only with evidence."
  type        = string
  default     = "XSMALL"
}

variable "analytics_schemas" {
  description = "Schemas Terraform pre-creates in the ANALYTICS database."
  type        = list(string)
  default     = ["STAGING", "MARTS"]
}

variable "data_retention_days" {
  description = "Time Travel retention. Cheap insurance in prod, waste in dev."
  type        = number
  default     = 1
}

variable "dbt_public_key_path" {
  description = "Path to the PEM public key for this environment's dbt service user. The private half never enters Terraform."
  type        = string
}

variable "shared_source_databases" {
  description = "Shared/imported databases the read role needs access to. Stands in for the EL layer this case scopes out."
  type        = list(string)
  default     = ["SNOWFLAKE_SAMPLE_DATA"]
}
