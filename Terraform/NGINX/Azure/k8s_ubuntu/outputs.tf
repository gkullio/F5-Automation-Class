output "Resource_Group_Name" {
  value = azurerm_resource_group.rg.name
}

output "Management_Public_IP" {
  value = "ssh -i ~/.ssh/id_rsa ${var.username}@${azurerm_linux_virtual_machine.kulland_ubuntu_vm.public_ip_address}"
}

output "Azure_Resource_Links" {
  value = {
    Azure_RG = "https://portal.azure.com/#@/resource/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/overview"
  }
}

output "K8s_internal_endpoints" {
  value = {
    demoapp     = "demoapp.lab.internal"
    dvga        = "dvga.lab.internal"
    dvwa        = "dvwa.lab.internal"
    juice-shop  = "juice-shop.lab.internal"
  }
}