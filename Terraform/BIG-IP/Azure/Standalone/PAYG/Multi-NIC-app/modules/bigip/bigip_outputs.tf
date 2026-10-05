output management_public_ip {
    value = azurerm_public_ip.management_pubip.ip_address
}

output external_public_ip {
    value = azurerm_public_ip.external_pubip.ip_address
}
