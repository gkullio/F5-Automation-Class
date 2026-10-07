output "vnet_id" {
  description   = "The ID of the virtual network"
  value         = azurerm_virtual_network.vnet.id
}
output "mgmt_subnet_id" {
  description   = "The ID of the management subnet"
  value         = azurerm_subnet.mgmt.id
}