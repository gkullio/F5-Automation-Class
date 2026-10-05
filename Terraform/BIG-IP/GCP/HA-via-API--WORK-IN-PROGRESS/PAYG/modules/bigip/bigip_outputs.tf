# ---- Primary (bigip1) -------------------------------------------------------
output "mgmt_public_ip_1"      { value = google_compute_address.mgmt_1.address }
output "mgmt_private_ip_1"     { value = google_compute_address.mgmt_internal_1.address }
output "external_public_ip_1"  { value = google_compute_address.external_1.address }
output "external_private_ip_1" { value = google_compute_address.external_internal_1.address }
output "internal_private_ip_1" { value = google_compute_address.internal_internal_1.address }
output "instance_name_1"       { value = google_compute_instance.bigip1.name }
output "instance_id_1"         { value = google_compute_instance.bigip1.instance_id }

# ---- Secondary (bigip2) ----------------------------------------------------
output "mgmt_public_ip_2"      { value = google_compute_address.mgmt_2.address }
output "mgmt_private_ip_2"     { value = google_compute_address.mgmt_internal_2.address }
output "external_public_ip_2"  { value = google_compute_address.external_2.address }
output "external_private_ip_2" { value = google_compute_address.external_internal_2.address }
output "internal_private_ip_2" { value = google_compute_address.internal_internal_2.address }
output "instance_name_2"       { value = google_compute_instance.bigip2.name }
output "instance_id_2"         { value = google_compute_instance.bigip2.instance_id }

# ---- Shared -----------------------------------------------------------------
output "image_name"              { value = data.google_compute_image.f5.name }
output "vip_public_ip"           { value = google_compute_address.vip.address }
output "external_floating_ip"    { value = google_compute_address.external_floating.address }
output "internal_floating_ip"    { value = google_compute_address.internal_floating.address }
output "cfe_state_bucket"        { value = google_storage_bucket.cfe_state.name }
