variable xc_api_creds {
    type = string
    description = "path to .p12 API certificate file"
}

variable xc_api_url {
    type = string
    description = "https url of your tenant. ex: https://<tenant-name>.console.ves.volterra.io/api"
}

variable my_name {
    type = string
    description = "Your name to easily find your configuration"
}

variable xc_namespace {
    type = string
    description = "Your Distibuted Cloud namespace"
}

variable delegated_dns_domain {
    type = string
    description = "The delegated domain of your choice that is a part of the tenant"
    default = "amer-ent.f5demos.com"
}

variable origin_pool_name {
    type = string
    description = "Name of the Origin Pool you want to advertise in your HTTP LB"
}

variable app_fw_name {
    type = string
    description = "Name of the Web App Firewall in your namespace you want to use in your HTTP LB"
}

# --- IP Reputation Options ---
variable "enable_ip_reputation" {
    type        = bool
    description = "Enable IP reputation-based threat filtering on the load balancer."
    default     = true
}

variable "ip_threat_categories" {
    type        = list(string)
    description = "List of IP threat categories to block when enable_ip_reputation is true."
    default     = [
        "SPAM_SOURCES",
        "WINDOWS_EXPLOITS",
        "WEB_ATTACKS",
        "BOTNETS",
        "SCANNERS",
        "DENIAL_OF_SERVICE",
        "REPUTATION",
        "PHISHING",
        "PROXY",
        "NETWORK",
        "TOR_PROXY",
        "MOBILE_THREATS"
        ]
}