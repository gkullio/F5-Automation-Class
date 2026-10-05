output "mgmt_vpc_self_link"        { value = google_compute_network.mgmt.self_link }
output "mgmt_vpc_name"             { value = google_compute_network.mgmt.name }
output "mgmt_subnet_self_link"     { value = google_compute_subnetwork.mgmt.self_link }

output "external_vpc_self_link"    { value = google_compute_network.external.self_link }
output "external_vpc_name"         { value = google_compute_network.external.name }
output "external_subnet_self_link" { value = google_compute_subnetwork.external.self_link }

output "internal_vpc_self_link"    { value = google_compute_network.internal.self_link }
output "internal_vpc_name"         { value = google_compute_network.internal.name }
output "internal_subnet_self_link" { value = google_compute_subnetwork.internal.self_link }
