output "management_public_ip"  { value = google_compute_address.mgmt.address }
output "management_private_ip" { value = google_compute_instance.bigip.network_interface[0].network_ip }
output "external_public_ip"    { value = google_compute_address.external.address }
output "external_private_ip"   { value = google_compute_address.external_internal.address }
output "internal_private_ip"   { value = google_compute_address.internal_internal.address }
output "instance_name"         { value = google_compute_instance.bigip.name }
output "instance_id"           { value = google_compute_instance.bigip.instance_id }
output "image_name"            { value = data.google_compute_image.f5.name }
