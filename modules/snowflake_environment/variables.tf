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
