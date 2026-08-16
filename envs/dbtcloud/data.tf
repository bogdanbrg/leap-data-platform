# Read the Snowflake object names from the other two states rather than
# hardcoding them. If a name changes there, it changes here.

data "terraform_remote_state" "dev" {
  backend = "remote"
  config = {
    organization = "bogdan-leap"
    workspaces   = { name = "leap-dev" }
  }
}

data "terraform_remote_state" "prod" {
  backend = "remote"
  config = {
    organization = "bogdan-leap"
    workspaces   = { name = "leap-prod" }
  }
}

locals {
  snowflake_account = "GASKGVJ-GF65092"
  dev               = data.terraform_remote_state.dev.outputs
  prod              = data.terraform_remote_state.prod.outputs
}
