# Phase 1 — KVM Infrastructure Setup

## Overview

The infrastructure was built locally using Proxmox VE as the KVM-based hypervisor. OPNsense is used as the firewall/router to manage private network traffic and isolate the Kubernetes lab from the public network.

The goal of Phase 1 was to prepare the virtual infrastructure required for a production-style Kubernetes cluster, including role-based VM planning, network separation, static addressing, kernel/container prerequisites, SSH hardening, and administrative permissions.

---

# Task 1.1 — Create the Virtual Machines

## Hypervisor Platform

Proxmox VE is used as the virtualization platform. Proxmox provides KVM/QEMU virtual machines, Linux bridge networking, VM snapshots, backups, and resource management.

The physical lab host has limited resources, so the design prioritizes the mandatory cluster, persistent storage, and application platform components before optional services such as CI/CD, registry, and full observability.

## Physical Host

| Component         | Specification     |
| ----------------- | ----------------- |
| CPU               | AMD Ryzen 5 5600X |
| RAM               | 16 GB             |
| Hypervisor        | Proxmox VE        |
| Firewall / Router | OPNsense          |

## Virtual Machine Role Plan

| VM             |        Management IP |      Storage IP | Role                         |
| -------------- | -------------------: | --------------: | ---------------------------- |
| `kubemaster-1` |     `192.168.30.240` | `192.168.32.11` | Kubernetes control plane     |
| `kubemaster-2` |     `192.168.30.241` | `192.168.32.12` | Kubernetes control plane     |
| `kubemaster-3` |     `192.168.30.242` | `192.168.32.13` | Kubernetes control plane     |
| `kubeworker-1` |     `192.168.30.243` | `192.168.32.21` | Kubernetes worker            |
| `kubeworker-2` |     `192.168.30.244` | `192.168.32.22` | Kubernetes worker            |
| `nfs`          |     `192.168.30.235` | `192.168.32.10` | Dedicated NFS storage server |
| `opnsense`     | Environment-specific |             N/A | Firewall / router            |

## Load Balancer Role

A separate load-balancer VM was intentionally not created for application traffic.

Instead, the load-balancer role is implemented inside Kubernetes:

| Load Balancer Function                | Implementation                    |
| ------------------------------------- | --------------------------------- |
| Kubernetes API high availability      | `kube-vip`                        |
| Kubernetes API VIP                    | `192.168.30.250`                  |
| Application LoadBalancer services     | Planned `kube-vip-cloud-provider` |
| Planned application LoadBalancer pool | `192.168.30.200-192.168.30.219`   |

This design was chosen because the applications run inside Kubernetes, so exposing them through Kubernetes-native `LoadBalancer` services is more appropriate than adding a separate external HAProxy/NGINX VM in this constrained lab.

## Operating System Choice

Ubuntu Server 24.04 LTS was selected for the Kubernetes nodes and storage VM.

Ubuntu Server 24.04 LTS was chosen because:

* It has a long-term support lifecycle.
* It provides a modern Linux kernel suitable for container workloads.
* It has strong compatibility with Kubernetes, kubeadm, containerd, and common CSI drivers.
* It is widely documented and operationally familiar.
* It is lightweight enough for a constrained local KVM lab.

This makes it a practical choice for a production-style Kubernetes test environment.

---

# Task 1.2 — Configure KVM Networking

## Network Design

The environment uses multiple Proxmox virtual bridges and static IP addressing.

| Network                             |            Subnet | Purpose                                                                    |
| ----------------------------------- | ----------------: | -------------------------------------------------------------------------- |
| Management / private access network | `192.168.30.0/24` | SSH, Kubernetes API, node management, Headlamp, private application access |
| Storage network                     | `192.168.32.0/24` | NFS traffic between Kubernetes nodes and the storage VM                    |
| Pod network                         |   `10.244.0.0/16` | Kubernetes pod networking through Canal                                    |
| Service network                     |    `10.96.0.0/12` | Kubernetes ClusterIP services                                              |

## Proxmox Bridge Layout

| Proxmox Bridge | Purpose                              |
| -------------- | ------------------------------------ |
| `vmbr0`        | WAN / upstream side used by OPNsense |
| `vmbr1`        | Private management network           |
| `vmbr2`        | Isolated Kubernetes storage network  |

`vmbr2` is an isolated bridge used for NFS traffic only. It has no physical uplink and no default gateway configured on the guest VMs. This keeps storage traffic separate from management, API, dashboard, and application access traffic.

## VM Network Interface Layout

Each Kubernetes node uses two virtual NICs.

| Interface | Network           | Purpose                                         |
| --------- | ----------------- | ----------------------------------------------- |
| `ens18`   | `192.168.30.0/24` | Management, SSH, Kubernetes API, private access |
| `ens19`   | `192.168.32.0/24` | Storage traffic to NFS                          |

The NFS server also uses two virtual NICs:

| Interface |          IP Address | Purpose             |
| --------- | ------------------: | ------------------- |
| `ens18`   | `192.168.30.235/24` | Management access   |
| `ens19`   |  `192.168.32.10/24` | NFS storage traffic |

Only `ens18` has a default gateway. The storage interface `ens19` has no gateway.

## Static IP Addressing

Static IP addressing is used for all infrastructure nodes to ensure stable Kubernetes control plane membership, predictable NFS mounts, and reliable troubleshooting.

| Host           |    Management IP |      Storage IP |
| -------------- | ---------------: | --------------: |
| `kubemaster-1` | `192.168.30.240` | `192.168.32.11` |
| `kubemaster-2` | `192.168.30.241` | `192.168.32.12` |
| `kubemaster-3` | `192.168.30.242` | `192.168.32.13` |
| `kubeworker-1` | `192.168.30.243` | `192.168.32.21` |
| `kubeworker-2` | `192.168.30.244` | `192.168.32.22` |
| `nfs`          | `192.168.30.235` | `192.168.32.10` |

## Kubernetes API Virtual IP

The Kubernetes API is exposed through a highly available virtual IP:

```text
192.168.30.250
```

This VIP is provided by `kube-vip`.

## Network Topology Diagram

```text
                         Internet / Upstream
                                |
                              vmbr0
                                |
                            OPNsense
                                |
                     Private LAN / Management
                         192.168.30.0/24
                                |
                              vmbr1
                                |
     ---------------------------------------------------------
     |            |            |            |           |     |
kubemaster-1  kubemaster-2  kubemaster-3  worker-1  worker-2  nfs
192.168.30.240 .241         .242          .243      .244      .235
     |            |            |            |           |      |
     ----------------------------------------------------------
                         Kubernetes API VIP
                          192.168.30.250


                  Isolated Storage Network
                      192.168.32.0/24
                              vmbr2
                                |
     ---------------------------------------------------------
     |            |            |            |           |     |
kubemaster-1  kubemaster-2  kubemaster-3  worker-1  worker-2  nfs
192.168.32.11 .12          .13           .21       .22       .10
                                                               |
                                                       /srv/nfs/k8s
```

## Storage Network Validation

Manual NFS mounting was tested successfully from Kubernetes nodes to the NFS server over the storage network.

Example validation command:

```bash
sudo mkdir -p /mnt/nfs-test
sudo mount -t nfs4 192.168.32.10:/srv/nfs/k8s /mnt/nfs-test
echo "test from $(hostname)" | sudo tee /mnt/nfs-test/test-$(hostname).txt
sudo umount /mnt/nfs-test
```

The test file was verified on the NFS server under:

```text
/srv/nfs/k8s
```

This confirms that Kubernetes nodes can reach persistent storage through the isolated `192.168.32.0/24` network.

---

# Task 1.3 — System-Level Configuration

## Kernel Modules

The following kernel modules were configured on the Kubernetes nodes:

```text
overlay
br_netfilter
```

These are required for container overlay filesystems and Kubernetes network packet handling through Linux bridges.

Verification commands:

```bash
lsmod | grep overlay
lsmod | grep br_netfilter
```

## Sysctl Configuration

The following sysctl settings were applied:

```text
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
```

These settings allow bridged IPv4/IPv6 traffic to be processed correctly by iptables and allow forwarding required by Kubernetes networking.

Verification commands:

```bash
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
```

## Swap Disabled

Swap was disabled on all Kubernetes nodes.

Verification command:

```bash
swapon --show
```

Expected result:

```text
No output
```

## Container Runtime

`containerd` is installed and running on all Kubernetes nodes.

The runtime is configured with the systemd cgroup driver:

```text
SystemdCgroup = true
```

Verification commands:

```bash
systemctl status containerd --no-pager
containerd --version
grep -n "SystemdCgroup" /etc/containerd/config.toml
```

`containerd` was selected because it is a production-grade Kubernetes container runtime and integrates directly with kubelet through the CRI interface.

## Kubernetes Packages

The following packages were installed on all Kubernetes nodes:

```text
kubeadm
kubelet
kubectl
```

The packages were marked on hold to avoid accidental version drift:

```bash
apt-mark hold kubelet kubeadm kubectl
```

Verification command:

```bash
apt-mark showhold
```

## NFS Client Package

The NFS client package was installed on all Kubernetes nodes:

```text
nfs-common
```

This is required because the actual NFS mount happens on the Kubernetes node where a pod using an NFS-backed PVC is scheduled.

The NFS server VM uses:

```text
nfs-kernel-server
```

## Administrative User and Permissions

A dedicated non-root administrative user is used on all VMs:

```text
anik
```

The user `anik` is a member of the `sudo` group on:

```text
kubemaster-1
kubemaster-2
kubemaster-3
kubeworker-1
kubeworker-2
nfs
```

Verification commands:

```bash
id anik
groups anik
sudo -l -U anik
```

Expected sudo permission:

```text
(ALL : ALL) ALL
```

This allows administrative work to be performed through sudo instead of direct root login.

## SSH Security

SSH access has been hardened on all Kubernetes and storage VMs.

The following SSH settings are enforced:

```text
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

This means:

* SSH key authentication is required.
* Password-based login is disabled.
* Direct root login is disabled.
* The non-root `anik` user is used for administration.
* Privileged commands are run through `sudo`.

Effective configuration can be verified with:

```bash
sudo sshd -T | egrep 'pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin|permitemptypasswords|x11forwarding|maxauthtries|clientaliveinterval|clientalivecountmax'
```

Expected output includes:

```text
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
permitrootlogin no
permitemptypasswords no
x11forwarding no
maxauthtries 3
clientaliveinterval 300
clientalivecountmax 2
```

Password-only login was tested using:

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password anik@<VM_IP>
```

Expected result:

```text
Permission denied
```

---

# Phase 1 Completion Checklist

| Requirement                                                              | Status   |
| ------------------------------------------------------------------------ | -------- |
| Multiple KVM virtual machines provisioned                                | Complete |
| Linux OS installed on VMs                                                | Complete |
| Control plane roles assigned                                             | Complete |
| Worker node roles assigned                                               | Complete |
| Dedicated storage server role assigned                                   | Complete |
| Load balancer role planned through Kubernetes-native kube-vip components | Complete |
| Linux distribution justified                                             | Complete |
| KVM/Proxmox networking configured                                        | Complete |
| Static IP addressing configured                                          | Complete |
| Isolated storage network implemented                                     | Complete |
| Multi-NIC layout implemented                                             | Complete |
| Network topology documented                                              | Complete |
| Kernel modules configured                                                | Complete |
| Sysctl tuning applied                                                    | Complete |
| Swap disabled                                                            | Complete |
| Production-grade container runtime installed                             | Complete |
| SSH key-based authentication enforced                                    | Complete |
| Password SSH login disabled                                              | Complete |
| Root SSH login disabled                                                  | Complete |
| Dedicated sudo user configured                                           | Complete |

---

# Phase 1 Design Summary

Phase 1 establishes the infrastructure foundation for the Kubernetes cluster.

The design separates major responsibilities across dedicated VMs:

* Control plane nodes manage the Kubernetes API and cluster state.
* Worker nodes run application workloads.
* A dedicated NFS VM provides persistent storage.
* OPNsense handles private routing and firewalling.
* kube-vip provides the Kubernetes API virtual IP.
* Application load balancing is planned through Kubernetes-native LoadBalancer services.

The network design separates management and storage traffic using different Proxmox bridges and subnets. This keeps NFS persistent-volume traffic isolated from SSH, Kubernetes API, dashboard, and private application access traffic.

The system-level configuration prepares the VMs for Kubernetes by enabling required kernel modules, sysctl values, container runtime settings, and swap configuration. SSH access is hardened across all VMs using key-only login and a dedicated sudo user.
