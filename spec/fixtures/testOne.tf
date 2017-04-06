terraform {
  required_version = "> 0.9.0"
  backend "consul" {
    address = "127.0.0.1:8500"
    path    = "terraform/testOne"
  }
}

provider "consul" {
  address = "127.0.0.1:8500"
}

variable "foo" { default = "bar" }

resource "consul_keys" "testOne" {
  key {
    path  = "testOne"
    value = "${var.foo}"
  }
}

output "foo_variable" { value = "${var.foo}" }
