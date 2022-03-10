variable "resource-group-location" {
  type    = string
  default = "eastus"
}

variable "publickey" {
  type    = string
  default = "tf-cloud-init.pub"
}

variable "userdata" {
  type    = string
  default = "add-web-app-ssh.yaml"
}