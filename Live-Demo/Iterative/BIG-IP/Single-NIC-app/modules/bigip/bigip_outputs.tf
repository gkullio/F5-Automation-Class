output management_public_ip {
    value = azurerm_public_ip.management_pubip.ip_address
}
output management_private_ip {
    value = azurerm_network_interface.management_nic.private_ip_addresses
}
