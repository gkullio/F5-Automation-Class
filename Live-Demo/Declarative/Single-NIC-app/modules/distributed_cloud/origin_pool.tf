resource "volterra_origin_pool" "bigip_pool" {
  name      = "${var.my_name}-demoapp-pool"
  namespace = var.xc_namespace
  endpoint_selection     = "LOCAL_PREFERRED"
  loadbalancer_algorithm = "LB_OVERRIDE"
  origin_servers {
    public_ip {
        ip = var.public_ip
    }
  }
  port = 443
  use_tls {
    skip_server_verification = true
    tls_config {
       default_security = true
    }
  }
}