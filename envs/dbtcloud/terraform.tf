terraform {
  required_version = ">= 1.9"

  cloud {
    organization = "bogdan-leap"

    workspaces {
      name = "leap-dbtcloud"
    }
  }

  required_providers {
    dbtcloud = {
      source  = "dbt-labs/dbtcloud"
      version = "~> 1.0"
    }
  }
}

# Credentials come from DBT_CLOUD_ACCOUNT_ID / DBT_CLOUD_TOKEN / DBT_CLOUD_HOST_URL
# in the environment, so no secret appears in this repo.
provider "dbtcloud" {}
