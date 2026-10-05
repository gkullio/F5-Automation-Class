terraform {
  required_providers {
    volterra = {
      source = "volterraedge/volterra"
      version = "0.13.2"
    }
  }
}

provider "volterra" {
  api_p12_file     = "${path.module}/${var.xc_api_creds}"
  url              = var.xc_api_url
}