terraform {
  required_version = "> 0.9.0"
  backend "consul" {
    address = "127.0.0.1:8500"
    path    = "terraform/testThreeBaz"
  }
}

provider "consul" {
  address = "127.0.0.1:8500"
  version = "1.0.0"
}

variable "foo" {}

resource "consul_keys" "testThreeBaz" {
  key {
    path  = "testThreeBaz/foo"
    value = "${var.foo}"
  }
}

output "foo_variable" { value = "${var.foo}" }
