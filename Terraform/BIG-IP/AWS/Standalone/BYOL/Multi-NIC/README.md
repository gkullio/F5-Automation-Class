# BIG-IP on AWS — Multi-NIC (3-NIC)

Deploys a single BIG-IP VE on AWS with three network interfaces:

| Interface | BIG-IP mapping | Subnet          | Purpose                                |
|-----------|---------------|-----------------|----------------------------------------|
| eth0      | mgmt          | 10.245.1.0/24   | Management — SSH, TMUI (port 443)      |
| eth1      | 1.1           | 10.245.10.0/24  | External — virtual-server traffic      |
| eth2      | 1.2           | 10.245.20.0/24  | Internal — pool-member / server-side   |

## Key differences from the Single-NIC build

- **Dedicated management interface.** The GUI is on port **443** (not 8443)
  because httpd no longer shares an interface with TMM.
- **Separate security groups** per interface: management allows only admin
  source addresses on SSH/443; external allows application traffic; internal
  allows all VPC traffic.
- **Explicit ENIs.** `aws_network_interface` resources are created for each
  subnet and attached via `network_interface` blocks on the instance.
  `source_dest_check = false` is set on external and internal (data-plane)
  interfaces only.
- **Two Elastic IPs.** One on management (admin access + DNS record), one on
  external (virtual-server traffic from the internet).
- **DO VLANs + Self-IPs.** The onboarding template configures:
  - `external_vlan` (1.1) + `external_self` with the ENI's private IP
  - `internal_vlan` (1.2) + `internal_self` with the ENI's private IP
  - A TMM-level default route via the external subnet gateway

## Before your first apply

1. **Accept the AWS Marketplace offer** for the BIG-IP AMI (same as 1-NIC).
2. **Confirm the AMI name** — `f5_ami_search_name` defaults to
   `*BIGIP-17*PAYG-Best Plus 25Mbps*`.
3. **Set credentials** — `aws_profile` or OIDC, plus Azure SP for Key Vault
   and DNS.
4. Run `terraform init` then `terraform plan`.

## Cross-cloud dependencies

Identical to the Single-NIC build:
- DNS zone — Azure DNS (kulland.info)
- Wildcard certificate — Azure Key Vault
- DO / AS3 / CrowdStrike artifacts — Azure blob storage

## Subnet layout

```
VPC 10.245.0.0/16
├── mgmt       10.245.1.0/24   (public — IGW route)
├── external   10.245.10.0/24  (public — IGW route)
└── internal   10.245.20.0/24  (public — IGW route, move to private/NAT for prod)
```

All three subnets currently share the public route table for lab convenience.
In production, move the internal subnet to a private route table behind a NAT
gateway.

## Gotchas

- **Instance type must support 3+ ENIs.** m5.xlarge supports up to 4 ENIs;
  m5.2xlarge (the default) supports up to 4 as well. t3.micro only supports 2.
- **ENI ordering matters.** device_index 0 = management, 1 = external,
  2 = internal. BIG-IP maps these to mgmt, 1.1, 1.2 respectively.
- **Self-IP addresses are derived from the ENI private IPs.** AWS assigns them
  from the subnet CIDR; Terraform passes them into the DO declaration. The
  /24 prefix in the DO self-IP must match your subnet mask.
- **external_gw** must be the first usable IP in the external subnet CIDR
  (the AWS VPC router). For 10.245.10.0/24 that is 10.245.10.1.
- **Template edits rebuild the instance** (`user_data_replace_on_change = true`).
- **CrowdStrike toggle** works the same as the 1-NIC build.
