# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }
  # Configure Terraform Cloud provider
  cloud {
    organization = "Omegalul"
    workspaces {
      name = "demo"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg-demo" {
  name     = var.resource-group-name
  location = var.resource-group-location
}

resource "azurerm_virtual_network" "vnet-demo" {
  name                = "vnet-demo"
  location            = var.resource-group-location
  resource_group_name = var.resource-group-name
  address_space       = ["10.0.0.0/8"]
}

resource "azurerm_subnet" "snet-demo" {
  name                 = "snet-demo"
  resource_group_name  = var.resource-group-name
  virtual_network_name = azurerm_virtual_network.vnet-demo.name
  address_prefixes     = ["10.11.1.0/24"]
}

resource "azurerm_public_ip" "pip-web1" {
  name                = "pip-web1"
  location            = var.resource-group-location
  resource_group_name = var.resource-group-name
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_network_interface" "nic-web1" {
  name                = "nic-web1"
  location            = var.resource-group-location
  resource_group_name = var.resource-group-name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet-demo.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip-web1.id
  }
}

resource "azurerm_linux_virtual_machine" "vm-demo-web1" {
  name                = "vm-demo-web1"
  location            = var.resource-group-location
  resource_group_name = var.resource-group-name
  size                = "Standard_F2"
  admin_username      = "demoroot"
  user_data           = filebase64(var.userdata)
  network_interface_ids = [azurerm_network_interface.nic-web1.id]
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
# End VM config

# Begin NAT config for web vm outbound connectivity (apt update, etc.)
# External IP address for NAT gateway
resource "azurerm_public_ip" "pip-nat" {
  name                = "pip-nat"
  location            = var.resource-group-location
  resource_group_name = var.resource-group-name
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
  location            = var.resource-group-location
  resource_group_name = var.resource-group-name
}
# Associate the NAT gateway with VMSS subnet
resource "azurerm_subnet_nat_gateway_association" "nat-gw-web" {
  subnet_id      = azurerm_subnet.snet-demo.id
  nat_gateway_id = azurerm_nat_gateway.nat-gateway.id
}
# End NAT config

# Begin NSG config
# Allow http and ssh access from the public WAN
resource "azurerm_network_security_group" "nsg-demo" {
  name                = "nsg-demo"
  location            = var.resource-group-location
  resource_group_name = var.resource-group-name

  security_rule {
    name                       = "http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ssh"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "web-association" {
  network_interface_id      = azurerm_virtual_network.vnet-demo.id
  network_security_group_id = azurerm_network_security_group.nsg-demo.id
}
# End NSG config

# Begin Bastion config
resource "azurerm_subnet" "snet-demo-bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource-group-name
  virtual_network_name = azurerm_virtual_network.vnet-demo.name
  address_prefixes     = ["10.11.2.0/24"]
}

resource "azurerm_public_ip" "bastion-public-ip" {
  name                = "bastion-public-ip"
  location            = var.resource-group-location
  resource_group_name = var.resource-group-name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "demo-bastion-1" {
  name                = "demo-bastion-1"
  location            = var.resource-group-location
  resource_group_name = var.resource-group-name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.snet-demo-bastion.id
    public_ip_address_id = azurerm_public_ip.bastion-public-ip.id
  }
}