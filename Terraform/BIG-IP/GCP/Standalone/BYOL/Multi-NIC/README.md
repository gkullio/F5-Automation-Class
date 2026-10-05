# BIG-IP on GCP - Multi-NIC (3-NIC)

Deploys a single BIG-IP VE on GCP with three network interfaces:

| Interface | BIG-IP mapping | VPC Network                    | Subnet CIDR     | Purpose                           |
|-----------|---------------|--------------------------------|-----------------|-----------------------------------|
| nic0      | mgmt          | bigip-gcp-3nic-mgmt-vpc       | 10.245.1.0/24   | Management - SSH, TMUI (port 443) |
| nic1      | 1.1           | bigip-gcp-3nic-external-vpc   | 10.245.10.0/24  | External - virtual-server traffic |
| nic2      | 1.2           | bigip-gcp-3nic-internal-vpc   | 10.245.20.0/24  | Internal - pool-member traffic    |

## Key GCP difference: separate VPC networks

**GCP requires each network interface to be in a different VPC network.** This
is the fundamental structural difference from AWS multi-NIC, where all ENIs
share one VPC with different subnets. The VPC module creates three separate
`google_compute_network` resources with one subnet each.

## Key differences from the Single-NIC build

- **Dedicated management interface.** GUI on port **443** (not 8443).
- **Firewall rules per VPC.** Each VPC network gets its own firewall rules,
  targeted by the same network tag.
- **Two static external IPs.** Management (admin access + DNS) and external
  (virtual servers). Internal has no external IP.
- **Pre-allocated internal IPs.** `google_compute_address` with
  `address_type = "INTERNAL"` reserves the data-plane IPs before the instance
  is created, avoiding a circular dependency with the startup script.
- **DO VLANs + Self-IPs.** Same as the AWS multi-NIC build: external_vlan
  (1.1), internal_vlan (1.2), self-IPs, and a TMM default route.

## Before your first apply

1. **Enable the Compute Engine API** in your GCP project.
2. **Verify the machine type.** 3 NICs requires >= 8 vCPUs. `n2-standard-8`
   (the default) supports up to 4 NICs.
3. **Find the right image name:**
   ```
   gcloud compute images list --project f5-7626-networks-public \
     --filter="name~bigip" --sort-by=~creationTimestamp --limit=10
   ```
4. **Set credentials** - `gcloud auth application-default login` for local
   runs, plus Azure SP for Key Vault and DNS.
5. Run `terraform init` then `terraform plan`.

## Cross-cloud dependencies

Identical to the AWS builds:
- DNS zone - Azure DNS (kulland.info)
- Wildcard certificate - Azure Key Vault
- DO / AS3 / CrowdStrike artifacts - Azure blob storage

## Network layout

```
VPC: bigip-gcp-3nic-mgmt-vpc
  └── mgmt       10.245.1.0/24

VPC: bigip-gcp-3nic-external-vpc
  └── external   10.245.10.0/24

VPC: bigip-gcp-3nic-internal-vpc
  └── internal   10.245.20.0/24
```

All three VPC networks have the default route to the internet gateway. In
production, remove the default route from the internal VPC and add a custom
route through the BIG-IP or a Cloud NAT.

## Gotchas

- **3 VPC networks, not 3 subnets.** GCP's per-NIC-per-VPC constraint means
  this project creates three networks, not one. Firewall rules, routes, and
  peering are per-network.
- **Machine type NIC limits.** < 8 vCPUs = max 2 NICs. n2-standard-8 = up
  to 4 NICs. n2-standard-16 = up to 8 NICs.
- **can_ip_forward** applies to ALL interfaces. GCP has no per-NIC control
  like AWS's per-ENI `source_dest_check`.
- **Internal IPs are pre-allocated.** `google_compute_address` with
  `address_type = "INTERNAL"` ensures the self-IP addresses are known at
  plan time, before the instance exists.
- **external_gw** is the first usable IP in the external subnet CIDR (the
  GCP VPC router). For 10.245.10.0/24 that is 10.245.10.1.
- **Startup script changes rebuild the instance.**
- **CrowdStrike toggle** works the same as all other builds.
