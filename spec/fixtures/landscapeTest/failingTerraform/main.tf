terraform {
  required_version = "> 0.9.0"
  backend "consul" {
    address = "127.0.0.1:8500"
    path    = "terraform/landscapeTestFailure"
  }
}

provider "consul" {
  address = "127.0.0.1:8500"
  version = "~> 1.0"
}

locals {
  keys = {
    foo = "foo2val"
    bar = "bar2val"
    baz = "baz2val"
  }
}

variable "foo" { default = "bar" }

resource "consul_key_prefix" "landscapeTest" {
  invalid_param = "whoCares"
}

output "foo_variable" { value = "${var.foo}" }
