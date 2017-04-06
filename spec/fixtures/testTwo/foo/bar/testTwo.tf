terraform {
  required_version = "> 0.9.0"
  backend "consul" {
    address = "127.0.0.1:8500"
  }
}

provider "consul" {
  address = "127.0.0.1:8500"
}

variable "foo" {}
variable "bar" { default = "bar" }

resource "consul_keys" "testTwo" {
  key {
    path  = "testTwo/foo"
    value = "${var.foo}"
  }
  key {
    path  = "testTwo/bar"
    value = "${var.bar}"
  }
}

output "foo_variable" { value = "${var.foo}" }
output "bar_variable" { value = "${var.bar}" }
