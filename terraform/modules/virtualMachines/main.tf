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

resource "azurerm_linux_virtual_machine" "demo-web1" {
  name                = "demo-web"
  location            = var.resource-group-location
  resource_group_name = var.resource-group-name
  size                = "Standard_F2"
  admin_username      = "demoroot"
  user_data           = filebase64(var.userdata)
  network_interface_ids = [
    azurerm_network_interface.nic-web1.id,
  ]
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