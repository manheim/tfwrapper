terraform {
  required_version = "> 0.9.0"
  backend "consul" {
    address = "127.0.0.1:8500"
    path    = "testOne"
  }
}

variable "foo" {}

output "foo_variable" { value = "${var.foo}" }
