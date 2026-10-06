output "NGINX_JWT_Info" {
  value = {
    f5_sat_expiry_date  = local.f5_sat_rfc3339
    f5_sat_epoch        = local.f5_sat_epoch
  }
}

output "Azure_Resource_Group_Info" {
  value = {
    Azure_Resource_Group_Name = azurerm_resource_group.rg.name
    Azure_RG_Link             = "https://portal.azure.com/#@/resource/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/overview"
  }
}

output "Management_Interface_Outputs" {
  value = {
    Management_Public_IP    = "ssh -i ~/.ssh/id_rsa ${var.username}@${azurerm_linux_virtual_machine.kulland_ubuntu_vm.public_ip_address}"
    Management_Private_IP   = azurerm_network_interface.management_nic.private_ip_address
  }
}

output "App_Access" {
  value = {
    Public_App_Access       = "http://${azurerm_linux_virtual_machine.kulland_ubuntu_vm.public_ip_address}"
  }
}


output "Virtual_Machine_Info" {
  value = {
    VM_Name                 = azurerm_linux_virtual_machine.kulland_ubuntu_vm.computer_name
    VM_Size                 = azurerm_linux_virtual_machine.kulland_ubuntu_vm.size
  }
}

