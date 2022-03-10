/*output "lb-public_ip" {
  value = azurerm_public_ip.lb-public-ip.ip_address
}
*/
output "nat-public_ip" {
  value = azurerm_public_ip.nat-public-ip.ip_address
}