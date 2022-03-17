output "pip-nat" {
  value = azurerm_public_ip.pip-nat.ip_address
}

output "pip-web" {
  value = azurerm_public_ip.pip-lb.ip_address
}