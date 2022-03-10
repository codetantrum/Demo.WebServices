output "pip-nat" {
  value = azurerm_public_ip.pip-nat.ip_address
}

output "pip-web" {
  value = azurerm_public_ip.pip-web1.ip_address
}