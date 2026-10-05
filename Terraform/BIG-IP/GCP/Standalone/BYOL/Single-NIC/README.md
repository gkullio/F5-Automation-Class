# BIG-IP on GCP - Single-NIC

Deploys a single BIG-IP VE on GCP with one network interface (management and
data plane share eth0), mirroring the AWS Single-NIC project.

## GCP vs AWS key differences

| Concept           | AWS                          | GCP                                      |
|-------------------|------------------------------|------------------------------------------|
| Network           | VPC (regional)               | VPC Network (global)                     |
| Firewall          | Security Group (per ENI)     | Firewall Rule (per VPC, targeted by tag) |
| Static IP         | Elastic IP                   | `google_compute_address`                 |
| source_dest_check | Per ENI attribute            | `can_ip_forward` on instance (all NICs)  |
| SSH key           | `aws_key_pair`               | Instance metadata `ssh-keys`             |
| Boot image        | AMI (per region)             | Image (global, from project)             |
| User data         | `user_data_base64`           | `metadata_startup_script`                |
| runtime-init      | `--cloud aws`                | `--cloud gcp`                            |

## Before your first apply

1. **Enable the Compute Engine API** in your GCP project.
2. **Find the right image name:**
   ```
   gcloud compute images list --project f5-7626-networks-public \
     --filter="name~bigip" --sort-by=~creationTimestamp --limit=10
   ```
3. **Set credentials** - `gcloud auth application-default login` for local
   runs, plus Azure SP for Key Vault and DNS.
4. Run `terraform init` then `terraform plan`.

## Cross-cloud dependencies

Identical to the AWS builds:
- DNS zone - Azure DNS (kulland.info)
- Wildcard certificate - Azure Key Vault
- DO / AS3 / CrowdStrike artifacts - Azure blob storage

## Gotchas

- **GUI on 8443.** Single-NIC means httpd cedes 443 to TMM, same as AWS.
- **can_ip_forward** applies to all interfaces (GCP has no per-NIC control).
- **No egress firewall rule needed.** GCP VPCs allow all egress by default.
- **Image names are exact.** GCP does not support wildcard AMI lookups; you
  must specify the full image name (or use a family if F5 publishes one).
- **Startup script changes rebuild the instance** - GCP replaces the instance
  when `metadata_startup_script` changes.
