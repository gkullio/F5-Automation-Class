terraform {
  required_providers {
    volterra = {
      source = "volterraedge/volterra"
      version = "0.13.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "~>3.0"
    }
  }
}