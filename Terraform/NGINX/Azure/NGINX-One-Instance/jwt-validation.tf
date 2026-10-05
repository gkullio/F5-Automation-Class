locals {
  # Split the NGINX data plane JWT into its three segments
  _jwt_parts          = split(".", file("${path.module}/secrets/nginx-repo.jwt"))
  _jwt_payload_b64url = local._jwt_parts[1]

  # Convert base64url → standard base64 (swap URL-safe chars)
  _jwt_payload_b64_raw = replace(replace(local._jwt_payload_b64url, "-", "+"), "_", "/")

  # Re-add base64 padding stripped by the JWT spec
  _pad_len         = length(local._jwt_payload_b64_raw) % 4
  _jwt_payload_b64 = (
    local._pad_len == 2 ? "${local._jwt_payload_b64_raw}==" :
    local._pad_len == 3 ? "${local._jwt_payload_b64_raw}=" :
    local._jwt_payload_b64_raw
  )

  # Decode and parse the JWT payload JSON
  _jwt_payload  = jsondecode(base64decode(local._jwt_payload_b64))
  f5_sat_epoch  = local._jwt_payload["f5_sat"]

  # Convert epoch → RFC3339 so timecmp() can compare it against timestamp()
  f5_sat_rfc3339 = timeadd("1970-01-01T00:00:00Z", "${local.f5_sat_epoch}s")
}

# Gate the entire deployment on a valid, non-expired f5_sat claim.
# Every resource depends on azurerm_resource_group.rg, which depends_on this,
# so a failed check blocks all resource creation.
resource "terraform_data" "jwt_validation" {
  input = local.f5_sat_epoch

  lifecycle {
    precondition {
      # Passes when today is on or before the f5_sat expiry date.
      # Fails (stops Terraform) when the SAT has expired.
      condition     = timecmp(timestamp(), local.f5_sat_rfc3339) <= 0
      error_message = "NGINX JWT validation failed: f5_sat expired on ${local.f5_sat_rfc3339}. Renew your NGINX subscription before deploying."
    }
  }
}
