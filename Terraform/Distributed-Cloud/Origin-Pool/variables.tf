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

variable public_ip {
    type = string
    description = "Public IP of the endpoint you want to advertise in XC"
}