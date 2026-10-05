output "vpc_self_link"         { value = google_compute_network.vpc.self_link }
output "vpc_name"              { value = google_compute_network.vpc.name }
output "mgmt_subnet_self_link" { value = google_compute_subnetwork.mgmt.self_link }
