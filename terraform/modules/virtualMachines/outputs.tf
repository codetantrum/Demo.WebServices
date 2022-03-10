output "azurerm_public_ip" {
  value = azurerm_public_ip.pip-web1.ip_address
}

output "nic-web1" {
  value = azurerm_network_interface.nic-web1
}

output "vnet-web" {
  value = azurerm_virtual_network.vnet-demo
}

output "snet-web" {
  value = azurerm_subnet.snet-demo
}

output "pip-web1" {
  value = azurerm_public_ip.pip-web1.ip_address
}