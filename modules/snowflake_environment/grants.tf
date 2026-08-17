########################################
# READ: usage down the hierarchy, then SELECT on objects
########################################

# Usage on both databases. Without this, nothing below is reachable.
resource "snowflake_grant_privileges_to_account_role" "read_db_usage" {
  provider          = snowflake.securityadmin
  for_each          = toset([snowflake_database.raw.name, snowflake_database.analytics.name])
  account_role_name = snowflake_account_role.read.name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "DATABASE"
    object_name = each.value
  }
}

# Usage on schemas that exist now.
resource "snowflake_grant_privileges_to_account_role" "read_all_schemas" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.read.name
  privileges        = ["USAGE"]

  on_schema {
    all_schemas_in_database = snowflake_database.analytics.name
  }
}

# Usage on schemas that do not exist yet. This is what lets dbt
# create a new schema at runtime without anyone editing Terraform.
resource "snowflake_grant_privileges_to_account_role" "read_future_schemas" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.read.name
  privileges        = ["USAGE"]

  on_schema {
    future_schemas_in_database = snowflake_database.analytics.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "read_all_objects" {
  provider          = snowflake.securityadmin
  for_each          = toset(["TABLES", "VIEWS"])
  account_role_name = snowflake_account_role.read.name
  privileges        = ["SELECT"]

  on_schema_object {
    all {
      object_type_plural = each.value
      in_database        = snowflake_database.analytics.name
    }
  }
}

# The key line of the whole platform: anything dbt creates from now on
# is readable, without a human granting anything.
resource "snowflake_grant_privileges_to_account_role" "read_future_objects" {
  provider          = snowflake.securityadmin
  for_each          = toset(["TABLES", "VIEWS"])
  account_role_name = snowflake_account_role.read.name
  privileges        = ["SELECT"]

  on_schema_object {
    future {
      object_type_plural = each.value
      in_database        = snowflake_database.analytics.name
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "read_warehouse" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.read.name
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.transform.name
  }
}

########################################
# WRITE: inherits READ, adds the ability to create
########################################

resource "snowflake_grant_account_role" "write_inherits_read" {
  provider         = snowflake.securityadmin
  role_name        = snowflake_account_role.read.name
  parent_role_name = snowflake_account_role.write.name
}

# CREATE SCHEMA is what lets each developer get their own dbt schema.
resource "snowflake_grant_privileges_to_account_role" "write_db" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.write.name
  privileges        = ["USAGE", "CREATE SCHEMA"]

  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.analytics.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "write_all_schemas" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.write.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE VIEW"]

  on_schema {
    all_schemas_in_database = snowflake_database.analytics.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "write_future_schemas" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.write.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE VIEW"]

  on_schema {
    future_schemas_in_database = snowflake_database.analytics.name
  }
}

########################################
# Hierarchy: access roles roll into the functional role,
# functional role rolls into SYSADMIN
########################################

resource "snowflake_grant_account_role" "transformer_gets_write" {
  provider         = snowflake.securityadmin
  role_name        = snowflake_account_role.write.name
  parent_role_name = snowflake_account_role.transformer.name
}

resource "snowflake_grant_account_role" "transformer_to_sysadmin" {
  provider         = snowflake.securityadmin
  role_name        = snowflake_account_role.transformer.name
  parent_role_name = "SYSADMIN"
}

# Shared databases need IMPORTED PRIVILEGES rather than ordinary grants.
# SNOWFLAKE_SAMPLE_DATA is our stand-in source, since ingestion is out of scope.
resource "snowflake_grant_privileges_to_account_role" "read_shared_sources" {
  provider          = snowflake.securityadmin
  for_each          = toset(var.shared_source_databases)
  account_role_name = snowflake_account_role.read.name
  privileges        = ["IMPORTED PRIVILEGES"]

  on_account_object {
    object_type = "DATABASE"
    object_name = each.value
  }
}

resource "snowflake_grant_privileges_to_account_role" "read_schema_usage" {
  provider          = snowflake.securityadmin
  for_each          = snowflake_schema.analytics
  account_role_name = snowflake_account_role.read.name
  privileges        = ["USAGE"]

  on_schema {
    schema_name = each.value.fully_qualified_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "read_schema_tables" {
  provider          = snowflake.securityadmin
  for_each          = snowflake_schema.analytics
  account_role_name = snowflake_account_role.read.name
  privileges        = ["SELECT"]

  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = each.value.fully_qualified_name
    }
  }
}
