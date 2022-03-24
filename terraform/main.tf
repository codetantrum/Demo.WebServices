# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
      # shorthand for allowing only patch releases within a specific minor release
      # https://www.terraform.io/language/providers/requirements#version-constraints
    }
  }
  # Configure Terraform Cloud provider
  # https://cloud.hashicorp.com/products/terraform
  cloud {
    organization = "Omegalul"
    workspaces {
      name = "demo-WebServices"
    }
  }

  required_version = ">= 1.1.0"
}
# At least 1 "features" block is required
provider "azurerm" {
  features {}
}

# All resources are stored in this group
resource "azurerm_resource_group" "rg-demo" {
  name     = var.rg-name
  location = var.rg-location
}

# All resources sit on this virtual network
resource "azurerm_virtual_network" "vnet-demo" {
  name                = "vnet-demo"
  location            = var.rg-location
  resource_group_name = azurerm_resource_group.rg-demo.name
  address_space       = ["10.0.0.0/8"]
}

# Backend web server subnet
resource "azurerm_subnet" "snet-demo" {
  name                 = "snet-demo"
  resource_group_name  = azurerm_resource_group.rg-demo.name
  virtual_network_name = azurerm_virtual_network.vnet-demo.name
  address_prefixes     = ["10.11.1.0/24"]
}

# External (public) IP address for frontend load balancer
# Standard SKU required for static allocation and for use with Standard SKU load balancer
resource "azurerm_public_ip" "pip-lb" {
  name                = "pip-lb"
  location            = var.rg-location
  resource_group_name = azurerm_resource_group.rg-demo.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Begin load balancer configuration
resource "azurerm_lb" "lb-demo" {
  name                = "lb-demo"
  location            = azurerm_resource_group.rg-demo.location
  resource_group_name = azurerm_resource_group.rg-demo.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "publicIPAddress"
    public_ip_address_id = azurerm_public_ip.pip-lb.id
  }
}

# Pool containing multiple web server NICs
resource "azurerm_lb_backend_address_pool" "backend-addr-pool" {
  loadbalancer_id = azurerm_lb.lb-demo.id
  name            = "backend-addr-pool"
}

# Load balancer probe to determine healthy backend nodes
resource "azurerm_lb_probe" "demoProbe" {
  resource_group_name = azurerm_resource_group.rg-demo.name
  loadbalancer_id     = azurerm_lb.lb-demo.id
  name                = "demoProbe"
  port                = 80
}

# Inbound load balancer rule to allow 80/tcp from the WAN to the backend web server pool
resource "azurerm_lb_rule" "demoHTTP" {
  resource_group_name            = azurerm_resource_group.rg-demo.name
  loadbalancer_id                = azurerm_lb.lb-demo.id
  name                           = "demoHTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend-addr-pool.id]
  frontend_ip_configuration_name = "publicIPAddress"
  probe_id                       = azurerm_lb_probe.demoProbe.id
}
# End load balancer configuration

# Begin web server VMSS configuration
# user_data comes from add-web-app-ssh.yaml; base64 encoding required
resource "azurerm_linux_virtual_machine_scale_set" "vmss-web" {
  name                  = "vmss-web"
  resource_group_name   = azurerm_resource_group.rg-demo.name
  location              = azurerm_resource_group.rg-demo.location
  sku                   = "Standard_F2"
  instances             = 2
  admin_username        = "demoroot"
  user_data             = filebase64(var.userdata)

  admin_ssh_key {
    username   = "demoroot"
    public_key = var.public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name = "nic-web"
    primary = true

    ip_configuration {
      name = "vmss-web"
      primary = true
      subnet_id = azurerm_subnet.snet-demo.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend-addr-pool.id]
    }
    network_security_group_id = azurerm_network_security_group.nsg-demo.id
  }
}
# End web server VM config

# Begin NAT config for outbound connectivity
# External IP address for NAT gateway
resource "azurerm_public_ip" "pip-nat" {
  name                = "pip-nat"
  location            = var.rg-location
  resource_group_name = azurerm_resource_group.rg-demo.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# Associate the public IP address with the NAT gateway
resource "azurerm_nat_gateway_public_ip_association" "nat-gw-association" {
  nat_gateway_id       = azurerm_nat_gateway.nat-gateway.id
  public_ip_address_id = azurerm_public_ip.pip-nat.id
}
# Create the NAT gateway
resource "azurerm_nat_gateway" "nat-gateway" {
  name                = "nat-gateway"
  location            = var.rg-location
  resource_group_name = azurerm_resource_group.rg-demo.name
}
# Associate the NAT gateway with web server subnet
resource "azurerm_subnet_nat_gateway_association" "nat-gw-web" {
  subnet_id      = azurerm_subnet.snet-demo.id
  nat_gateway_id = azurerm_nat_gateway.nat-gateway.id
}
# End NAT config

# Begin NSG config
# Allow HTTP access from the WAN
resource "azurerm_network_security_group" "nsg-demo" {
  name                = "nsg-demo"
  location            = var.rg-location
  resource_group_name = azurerm_resource_group.rg-demo.name

  security_rule {
    name                       = "demoHTTP"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "80"
    destination_address_prefix = "*"
    access                     = "Allow"
    direction                  = "Inbound"
    priority                   = 100
  }
}

resource "azurerm_subnet_network_security_group_association" "web-association" {
  subnet_id      = azurerm_subnet.snet-demo.id
  network_security_group_id = azurerm_network_security_group.nsg-demo.id
}
# End NSG config


# Begin Bastion config
# AzureBastionSubnet is the required name for this resource
resource "azurerm_subnet" "snet-demo-bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg-demo.name
  virtual_network_name = azurerm_virtual_network.vnet-demo.name
  address_prefixes     = ["10.11.2.0/24"]
}

resource "azurerm_public_ip" "bastion-public-ip" {
  name                = "bastion-public-ip"
  location            = var.rg-location
  resource_group_name = azurerm_resource_group.rg-demo.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "demo-bastion-1" {
  name                = "demo-bastion-1"
  location            = var.rg-location
  resource_group_name = azurerm_resource_group.rg-demo.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.snet-demo-bastion.id
    public_ip_address_id = azurerm_public_ip.bastion-public-ip.id
  }
}