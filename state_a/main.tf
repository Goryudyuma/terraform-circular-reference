terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

locals {
  other_state_path = "../state_b/terraform.tfstate"
}

# 相手の state ファイルが存在しないと terraform_remote_state はエラーになり、defaults も効かない。
# 循環しているのでどちらからも最初の apply ができなくなるため、ファイルがないときは読まずに 0 から始める。
data "terraform_remote_state" "other" {
  count   = fileexists(local.other_state_path) ? 1 : 0
  backend = "local"
  config = {
    path = local.other_state_path
  }
  defaults = {
    value = 0
  }
}

resource "terraform_data" "value" {
  input = try(data.terraform_remote_state.other[0].outputs.value, 0) + 1
}

output "value" {
  value = terraform_data.value.output
}
