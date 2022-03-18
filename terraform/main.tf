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
# At least 1 "features" blocks are required
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

# Associate the pool ID with each web server NIC
resource "azurerm_network_interface_backend_address_pool_association" "backend-addr-assoc" {
  count                   = 2
  network_interface_id    = element(azurerm_network_interface.nic-web.*.id, count.index)
  ip_configuration_name   = "config-${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend-addr-pool.id
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


# Web server network interface
# The count meta-argument creates the specified number of defined resources
# https://www.terraform.io/language/meta-arguments/count
resource "azurerm_network_interface" "nic-web" {
  count               = var.num-web-servers
  name                = "web-nic${count.index}"
  location            = azurerm_resource_group.rg-demo.location
  resource_group_name = azurerm_resource_group.rg-demo.name

  ip_configuration {
    name                          = "config-${count.index}"
    subnet_id                     = azurerm_subnet.snet-demo.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Availability set for web servers
# Fault domains are groups of VMs that share a common power source and network switch in Azure datacenters
# Update domains are groups of VMs that can be rebooted at the same time
resource "azurerm_availability_set" "av-set-web" {
  name                         = "av-set-web"
  location                     = azurerm_resource_group.rg-demo.location
  resource_group_name          = azurerm_resource_group.rg-demo.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

# Begin web server VM configuration
# user_data comes from add-web-app-ssh.yaml; base64 encoding required
resource "azurerm_linux_virtual_machine" "vm-web" {
  count                 = 2
  name                  = "vm-web-${count.index}"
  location              = azurerm_resource_group.rg-demo.location
  availability_set_id   = azurerm_availability_set.av-set-web.id
  resource_group_name   = azurerm_resource_group.rg-demo.name
  network_interface_ids = [element(azurerm_network_interface.nic-web.*.id, count.index)]
  size                  = "Standard_F2"
  admin_username        = "demoroot"
  user_data             = filebase64(var.userdata)

  admin_ssh_key {
    username   = "demoroot"
    public_key = file(var.publickey)
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
}
# End web server VM config

# Begin NAT config for web VM outbound connectivity (apt update, etc.)
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

resource "azurerm_network_interface_security_group_association" "web-association" {
  count = 2
  network_interface_id      = element(azurerm_network_interface.nic-web.*.id, count.index)
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