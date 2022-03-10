variable "userdata" {
  type    = string
  default = "add-web-app-ssh.yaml"
}

variable "resource-group-location" {
  type    = string
  default = "eastus"
}

variable "resource-group-name" {
  type    = string
  default = "rg-demo"
}

variable "publickey" {
  type    = string
  default = "tf-cloud-init.pub"
}