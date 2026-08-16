terraform {
  required_version = ">= 1.9"

  cloud {
    organization = "bogdan-leap"

    workspaces {
      name = "leap-dev"
    }
  }

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.19"
    }
  }
}
