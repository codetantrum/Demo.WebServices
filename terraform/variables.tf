variable "rg-name" {
  type    = string
  default = "eastus"
  description = "Resource group name"
}

variable "rg-location" {
  type    = string
  default = "eastus"
  description = "Resource group location"
}

variable "public_key" {
  type    = string
  description = "Public key for SSH access (add-web-app-ssh.yaml)"
}

variable "userdata" {
  type    = string
  default = "add-web-app-ssh.yaml"
  description = "Cloud init configuration file for web servers"
}

variable "num-web-servers" {
  type = number
  default = 2
  description = "Number of web server VMs and associated NICs to create"
}