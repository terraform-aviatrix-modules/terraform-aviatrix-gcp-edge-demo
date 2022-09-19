# avxedgedemo
Deploy Aviatrix Edge 2.0 in GCP (and eventually Azure.) AWS doesn't support nested virtualization, except on .metal instances.

# Why?
The idea is to demonstrate the deployment of Edge and the interface without burdening the customer with a local deploy.

It isn't realistic to use this module for performance testing as the intended environment and GCP/Azure nested virtualization are too different.

# How do I use it?
- Make sure your prefixes are defined in variables.tf. The code will statically point those prefixes to the VPC/VNET gateway. After that is up to you.
- Define appropriate Cloud Routes/Route Tables to send Aviatrix-bound traffic to the IP of the host VM. Although, there is no reason we can't use FRR/BGP to peer with NCC or ARS.
- Worst case, you can SSH to the Host VM and modify the underlying networking to suit. The nested Edge VM has to be modified from the controller.

## Current limitations
- Due to IPSec port limitations, we only have 1 Edge Gateway per Public IP.
  - GCP supports 1 Public IP per NIC, so we need multiple host VMs.
  - Azure supports multiple Public/Private ipconfigs, so we can multiple Edge VMs per host VM.

## Prerequisities
- Aviatrix Controller running 6.9.128 or later.
- Terraform must have GCP access to create a VM with nested virtualization per: https://cloud.google.com/compute/docs/instances/nested-virtualization/overview
- Terraform must have GCP access to create a Cloud Storage Bucket and upload files.
- The default Compute Service Account must have permissions to access the created bucket.
- Current Aviatrix Edge 2.0 image. Contact your account team.

## Provider credentials
Aviatrix: https://registry.terraform.io/providers/AviatrixSystems/aviatrix/latest/docs
- The Environment Variables are possibly the easiest way to go.
```
$ export AVIATRIX_CONTROLLER_IP = "1.2.3.4"
$ export AVIATRIX_USERNAME = "admin"
$ export AVIATRIX_PASSWORD = "password"
```
- Or can be coded in the main.tf file.

GCP: https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/getting_started

## What is deployed?

### Host VM config
- n2-standard-2 VM (2 vcpu, 8gb) with Ubuntu 22.04 LTS VM
  - single gvNIC
  - IP Forwarding enabled
  - Nested Virtualization enabled
- additional packages (not including dependencies)
  - python3 (Bash script is too painful)
  - qemu-kvm
  - libvirt-daemon-system
  - virtinst
  - libvirt-clients
  - bridge-utils
  - frr

### Libvirt config and VM deployment
- All files used are uploaded to the Storage Bucket then downloaded to the VM.
- Deploy 3 Libvirt networks for the 3 Edge NICs using XML files.
  - wan/eth0: Deployed as NAT with IP space from 192.168.122.0/24
  - lan/eth1: Deployed as open with provided IP space.
  - mgmt/eth2: Deployed as NAT with IP space from 192.168.122.122.0/24
- The Edge VM is deployed with virt-install, using 2 CPU/4gb RAM.