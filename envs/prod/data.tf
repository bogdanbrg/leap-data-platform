data "terraform_remote_state" "dev" {
  backend = "remote"

  config = {
    organization = "bogdan-leap"
    workspaces   = { name = "leap-dev" }
  }
}
