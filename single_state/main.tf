terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

resource "terraform_data" "a" {
  input = terraform_data.b.output + 1
}

resource "terraform_data" "b" {
  input = terraform_data.a.output + 1
}
