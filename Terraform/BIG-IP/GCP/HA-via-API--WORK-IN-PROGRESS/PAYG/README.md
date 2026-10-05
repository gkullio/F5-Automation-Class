# BIG-IP HA Pair on GCP - Multi-NIC (3-NIC) with Cloud Failover Extension

Deploys an active/standby BIG-IP VE HA pair on GCP with three network interfaces
per device, using the F5 Cloud Failover Extension (CFE) for automated failover
of GCP networking resources.

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │          GCP Forwarding Rule             │
                    │     VIP Public IP (TCP 1-65535)          │
                    │  target → active BIG-IP (CFE managed)    │
                    └───────────────┬─────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
  ┌─────┴──────┐            ┌───────┴───────┐           ┌──────┴──────┐
  │ mgmt VPC   │            │ external VPC  │           │ internal VPC│
  │ 10.245.1/24│            │ 10.245.10/24  │           │ 10.245.20/24│
  └─────┬──────┘            └───────┬───────┘           └──────┬──────┘
        │                           │                          │
   ┌────┼────┐                 ┌────┼────┐                ┌────┼────┐
   │nic0│nic0│                 │nic1│nic1│                │nic2│nic2│
   │ B1 │ B2 │                 │ B1 │ B2 │                │ B1 │ B2 │
   └────┴────┘                 └────┴────┘                └────┴────┘
  bigip-gcp-ha-01           + floating alias IP          + floating alias IP
  bigip-gcp-ha-02           (CFE managed)                (CFE managed)
```

| Interface | BIG-IP mapping | VPC Network                     | Subnet CIDR     | Purpose                           |
|-----------|---------------|---------------------------------|-----------------|-----------------------------------|
| nic0      | mgmt          | bigip-gcp-ha-3nic-mgmt-vpc     | 10.245.1.0/24   | Management - SSH, TMUI (port 443) |
| nic1      | 1.1           | bigip-gcp-ha-3nic-external-vpc | 10.245.10.0/24  | External - virtual-server traffic |
| nic2      | 1.2           | bigip-gcp-ha-3nic-internal-vpc | 10.245.20.0/24  | Internal - pool-member traffic    |

## How Cloud Failover Extension works

CFE automates GCP API calls during BIG-IP HA failover events:

1. **Alias IP movement** - floating self-IPs are GCP alias IPs on the active
   device's NICs. On failover, CFE removes them from the old active and adds
   them to the new active instance.
2. **Forwarding rule retargeting** - the public VIP forwarding rule initially
   targets the primary instance. On failover, CFE updates the rule's target
   to point at the newly active device.
3. **State persistence** - CFE stores failover state in a labeled GCS bucket
   so both devices share a consistent view of which resources are managed.

### CFE discovery via labels

CFE discovers its peers and managed resources using GCP labels:

| Resource             | Label                                   | Purpose                        |
|----------------------|-----------------------------------------|--------------------------------|
| Both BIG-IP instances | `f5_cloud_failover_label = bigip-gcp-ha` | Peer discovery                |
| CFE state GCS bucket  | `f5_cloud_failover_label = bigip-gcp-ha` | State file storage            |
| Forwarding rule        | *(discovered via instance target)*       | Public VIP retargeting        |

## Onboarding sequence

1. **Primary boots** → Runs runtime-init: DO (VLANs, self-IPs, floating
   self-IPs, ConfigSync, FailoverUnicast) → AS3 → CFE declaration.
2. **Secondary boots** (2-minute Terraform delay + startup wait loop) → Waits
   for primary's DO to report `OK` → Runs runtime-init: DO (same as primary +
   DeviceTrust pointing to primary + DeviceGroup for sync-failover) → AS3 → CFE.
3. HA pair is formed. CFE is active on both devices.

## Service account permissions

The shared SA gets project-level roles for CFE operations:

| Role                              | Purpose                                          |
|-----------------------------------|--------------------------------------------------|
| `roles/compute.instanceAdmin.v1`  | Modify alias IPs on instance NICs                |
| `roles/storage.admin`             | Read/write CFE state bucket + RPM bucket         |
| `roles/compute.networkAdmin`      | Update forwarding rule targets, manage routes    |

## Before your first apply

1. **Download the CFE RPM** and place it in `modules/bigip/rpm_files/`:
   ```
   # Download from https://github.com/F5Networks/f5-cloud-failover-extension/releases
   # Default expected filename: f5-cloud-failover-2.1.2-2.noarch.rpm
   ```
2. **Enable the Compute Engine API** in your GCP project.
3. **Verify the machine type.** 3 NICs requires >= 8 vCPUs. `n2-standard-8`
   (the default) supports up to 4 NICs.
4. **Find the right image name:**
   ```
   gcloud compute images list --project f5-7626-networks-public \
     --filter="name~bigip" --sort-by=~creationTimestamp --limit=10
   ```
5. **Set credentials** - `gcloud auth application-default login` for local
   runs, plus Azure SP for Key Vault and DNS.
6. Run `terraform init` then `terraform plan`.

## Key differences from the Standalone Multi-NIC build

- **Two instances** sharing the same 3 VPC networks
- **Floating self-IPs** on `traffic-group-1` (external + internal)
- **GCP alias IPs** on the active device's NICs for the floating addresses
- **Cloud Failover Extension** installed alongside DO and AS3
- **GCS state bucket** with CFE label for failover state persistence
- **Forwarding rule** with static public IP as the HA VIP
- **HA firewall rule** on mgmt VPC allowing inter-device trust traffic
- **Pre-allocated mgmt internal IPs** so the secondary can reach the primary
   during onboarding
- **Service account** with broader IAM roles for CFE API calls
- **`time_sleep` resource** gives primary a 2-minute head start
- **Secondary wait loop** polls primary's DO status before running runtime-init
- **`ignore_changes`** on `alias_ip_range` so Terraform doesn't fight CFE

## Verifying the HA pair

After deployment completes (~10-15 minutes):

```bash
# Check onboarding logs
ssh admin@<primary-mgmt-ip> 'tail -50 /var/log/cloud/startup-script.log'
ssh admin@<secondary-mgmt-ip> 'tail -50 /var/log/cloud/startup-script.log'

# Verify HA status via TMUI
# Login to either device → Device Management → Devices
# Both should show as "In Sync" with one Active, one Standby

# Verify CFE status
ssh admin@<primary-mgmt-ip>
curl -su admin: http://localhost:8100/mgmt/shared/cloud-failover/info | python3 -m json.tool
curl -su admin: http://localhost:8100/mgmt/shared/cloud-failover/declare | python3 -m json.tool

# Test failover (from the active device)
tmsh run sys failover standby
```

## Gotchas

- **CFE RPM must be downloaded manually.** It is not included in this repo.
  Place it in `modules/bigip/rpm_files/` before applying.
- **Both instances must be in the same zone.** GCP alias IPs and target
  instances require same-zone placement.
- **`ignore_changes` on alias IPs is critical.** Without it, every
  `terraform plan` after a failover shows drift because CFE moved the alias
  IPs to the other instance.
- **Startup script changes rebuild BOTH instances.** Any template modification
  triggers instance recreation.
- **Device trust timing.** If the primary takes longer than ~30 minutes to
  onboard, the secondary's wait loop will time out. Check serial console
  output if this happens.
- **Forwarding rule target is not updated by Terraform after initial apply.**
  CFE manages it. `terraform plan` will not show drift due to
  `ignore_changes`.
- **GTM is not provisioned** in the HA build (removed to reduce boot time).
  Add `gtm: nominal` to both templates' `myProvisioning` if needed.
