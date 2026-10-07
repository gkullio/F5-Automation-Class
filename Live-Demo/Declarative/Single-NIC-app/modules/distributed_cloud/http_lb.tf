resource "volterra_http_loadbalancer" "http_lb" {
  name      = "${var.my_name}-test-lb"
  namespace = var.xc_namespace

  advertise_on_public_default_vip = true
  disable_api_definition          = true
  no_challenge                    = true

  domains = ["${var.my_name}-lb.${var.delegated_dns_domain}"]

  # Uncomment this section if you want to use HTTPS Auto Cert
  # Then comment out the http block 
/*
  https_auto_cert {
    add_hsts             = true
    default_loadbalancer = false
    port                 = "443"
    http_redirect        = true
  }
*/  

  http {
    port = 80
    dns_volterra_managed = true
  }

  default_route_pools {
    pool {
      name                          = volterra_origin_pool.bigip_pool.name
      namespace                     = var.xc_namespace
    }
  }

  enable_malicious_user_detection   = false
  service_policies_from_namespace   = false
  source_ip_stickiness              = true
  disable_trust_client_ip_headers   = true
  user_id_client_ip                 = true
  default_sensitive_data_policy     = true
  disable_client_side_defense       = true
  disable_bot_defense               = true
  enable_threat_mesh                = true

  app_firewall {
    name                            = volterra_app_firewall.this.name
    namespace                       = var.xc_namespace
  }

## IP Reputation
  disable_ip_reputation             = var.enable_ip_reputation ? null : true
  dynamic "enable_ip_reputation" {
    for_each                        = var.enable_ip_reputation ? [1] : []
    content {
      ip_threat_categories          = var.ip_threat_categories
    }
  }

  more_option {
    request_headers_to_add {
      name                          = "geo-country"
      value                         = "$[geoip_country]"
      append                        = false
    }
    request_headers_to_add {
      name                          = "Access-Control-Allow-Origin"
      value                         = "*"
      append                        = false
    }
  }
}

