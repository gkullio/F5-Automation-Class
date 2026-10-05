output "management_public_ip"  { value = google_compute_address.mgmt.address }
output "management_private_ip" { value = google_compute_instance.bigip.network_interface[0].network_ip }
output "bigip_dns_fqdn"        { value = azurerm_dns_a_record.bigip.fqdn }
output "instance_name"         { value = google_compute_instance.bigip.name }
output "instance_id"           { value = google_compute_instance.bigip.instance_id }
output "image_name"            { value = data.google_compute_image.f5.name }
