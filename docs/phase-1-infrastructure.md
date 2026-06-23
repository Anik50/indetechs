# Phase 1 — KVM Infrastructure Setup

## Overview

The infrastructure was built locally using Proxmox VE as the KVM-based hypervisor. OPNsense is used as the firewall/router to manage private network traffic and isolate the Kubernetes lab from the public network.

The goal of Phase 1 was to prepare the virtual infrastructure required for a production-style Kubernetes cluster, including role-based VM planning, network separation, static addressing, kernel/container prerequisites, SSH hardening, and administrative permissions.

This phase establishes the VM, network, and operating-system foundation for the Kubernetes cluster built in Phase 2 and the application platform deployed in Phase 3.

## Task 1.1 — Create the Virtual Machines

### Hypervisor Platform

Proxmox VE is used as the virtualization platform. Proxmox provides KVM/QEMU virtual machines, Linux bridge networking, VM snapshots, backups, and resource management.

The physical lab host has limited resources, so the design prioritizes the mandatory cluster, persistent storage, and application platform components before optional services such as CI/CD, registry, and full observability.

### Physical Host

| Component         | Specification     |
| ----------------- | ----------------- |
| CPU               | AMD Ryzen 5 5600X |
| RAM               | 16 GB             |
| Hypervisor        | Proxmox VE        |
| Firewall / Router | OPNsense          |

### Lab HA Limitation

Although the Kubernetes cluster uses three control-plane VMs and a kube-vip API virtual IP, all VMs run on a single physical Proxmox host in this lab.

This provides Kubernetes-level control-plane resilience against individual VM or control-plane process failure, but it does not provide full physical-host redundancy.

In a production environment, the control-plane nodes, worker nodes, and storage components would be distributed across multiple hypervisor hosts or availability zones.

### Virtual Machine Role Plan

| VM             |        Management IP |      Storage IP | Role                         |
| -------------- | -------------------: | --------------: | ---------------------------- |
| `kubemaster-1` |     `192.168.30.240` | `192.168.32.11` | Kubernetes control plane     |
| `kubemaster-2` |     `192.168.30.241` | `192.168.32.12` | Kubernetes control plane     |
| `kubemaster-3` |     `192.168.30.242` | `192.168.32.13` | Kubernetes control plane     |
| `kubeworker-1` |     `192.168.30.243` | `192.168.32.21` | Kubernetes worker            |
| `kubeworker-2` |     `192.168.30.244` | `192.168.32.22` | Kubernetes worker            |
| `nfs`          |     `192.168.30.235` | `192.168.32.10` | Dedicated NFS storage server |
| `opnsense`     | Environment-specific |             N/A | Firewall / router            |

### Load Balancer Role

A separate load-balancer VM was intentionally not created for application traffic.

Instead, the load-balancer role is implemented using Kubernetes-native components:

| Load Balancer Function            | Implementation                          |
| --------------------------------- | --------------------------------------- |
| Kubernetes API high availability  | `kube-vip`                              |
| Kubernetes API VIP                | `192.168.30.250`                        |
| Application LoadBalancer services | `kube-vip` service LoadBalancer support |
| Application LoadBalancer pool     | `192.168.30.200-192.168.30.219`         |
| Application HTTP gateway          | Traefik                                 |
| Traefik LoadBalancer IP           | `192.168.30.200`                        |

This design was chosen because the applications run inside Kubernetes, so exposing them through Kubernetes-native `LoadBalancer` services is more appropriate than adding a separate external HAProxy/NGINX VM in this constrained lab.

kube-vip provides both the Kubernetes API virtual IP and the private LoadBalancer IPs for Kubernetes services. Traefik then acts as the in-cluster API gateway for HTTP application routing.

This keeps the design simple, avoids wasting limited lab resources on an additional load-balancer VM, and keeps application exposure controlled through Kubernetes manifests.

### Operating System Choice

Ubuntu Server 24.04.4 LTS was selected for the Kubernetes nodes and storage VM.

Ubuntu Server 24.04 LTS was chosen because:

* It has a long-term support lifecycle.
* It provides a modern Linux kernel suitable for container workloads.
* It has strong compatibility with Kubernetes, kubeadm, containerd, and common CSI drivers.
* It is widely documented and operationally familiar.
* It is lightweight enough for a constrained local KVM lab.

This makes it a practical choice for a production-style Kubernetes test environment.

## Task 1.2 — Configure KVM Networking

### Network Design

The environment uses multiple Proxmox virtual bridges and static IP addressing.

| Network                             |                          Subnet | Purpose                                                                    |
| ----------------------------------- | ------------------------------: | -------------------------------------------------------------------------- |
| Management / private access network |               `192.168.30.0/24` | SSH, Kubernetes API, node management, Headlamp, private application access |
| Storage network                     |               `192.168.32.0/24` | NFS traffic between Kubernetes nodes and the storage VM                    |
| Pod network                         |                 `10.244.0.0/16` | Kubernetes pod networking through Canal                                    |
| Service network                     |                  `10.96.0.0/12` | Kubernetes ClusterIP services                                              |
| kube-vip LoadBalancer pool          | `192.168.30.200-192.168.30.219` | Private Kubernetes `LoadBalancer` services                                 |
| Kubernetes API VIP                  |                `192.168.30.250` | Highly available Kubernetes API endpoint                                   |

### Proxmox Bridge Layout

| Proxmox Bridge | Purpose                              |
| -------------- | ------------------------------------ |
| `vmbr0`        | WAN / upstream side used by OPNsense |
| `vmbr1`        | Private management network           |
| `vmbr2`        | Isolated Kubernetes storage network  |

`vmbr2` is an isolated bridge used for NFS traffic only. It has no physical uplink and no default gateway configured on the guest VMs. This keeps storage traffic separate from management, API, dashboard, and application access traffic.

### VM Network Interface Layout

Each Kubernetes node uses two virtual NICs.

| Interface | Network           | Purpose                                                     |
| --------- | ----------------- | ----------------------------------------------------------- |
| `ens18`   | `192.168.30.0/24` | Management, SSH, Kubernetes API, private application access |
| `ens19`   | `192.168.32.0/24` | Storage traffic to NFS                                      |

The NFS server also uses two virtual NICs:

| Interface |          IP Address | Purpose             |
| --------- | ------------------: | ------------------- |
| `ens18`   | `192.168.30.235/24` | Management access   |
| `ens19`   |  `192.168.32.10/24` | NFS storage traffic |

Only `ens18` has a default gateway. The storage interface `ens19` has no gateway.

### Static IP Addressing

Static IP addressing is used for all infrastructure nodes to ensure stable Kubernetes control-plane membership, predictable NFS mounts, reliable service exposure, and easier troubleshooting.

| Host                       |                   Management IP |      Storage IP |
| -------------------------- | ------------------------------: | --------------: |
| `kubemaster-1`             |                `192.168.30.240` | `192.168.32.11` |
| `kubemaster-2`             |                `192.168.30.241` | `192.168.32.12` |
| `kubemaster-3`             |                `192.168.30.242` | `192.168.32.13` |
| `kubeworker-1`             |                `192.168.30.243` | `192.168.32.21` |
| `kubeworker-2`             |                `192.168.30.244` | `192.168.32.22` |
| `nfs`                      |                `192.168.30.235` | `192.168.32.10` |
| Kubernetes API VIP         |                `192.168.30.250` |             N/A |
| kube-vip LoadBalancer pool | `192.168.30.200-192.168.30.219` |             N/A |
| Traefik LoadBalancer IP    |                `192.168.30.200` |             N/A |

The kube-vip LoadBalancer pool is kept separate from the static VM addresses to avoid IP conflicts.

### Kubernetes API Virtual IP

The Kubernetes API is exposed through a highly available virtual IP:

```text
192.168.30.250
```

This VIP is provided by kube-vip and is used as the stable API endpoint for cluster administration and node control-plane communication.

### Application LoadBalancer IPs

Application `LoadBalancer` services use kube-vip service LoadBalancer support with the following private IP pool:

```text
192.168.30.200-192.168.30.219
```

Traefik is assigned the first address from this pool:

```text
192.168.30.200
```

Application access flows through Traefik rather than direct NodePort or direct pod access.

### Network Topology Diagram

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
     -----------------------------------------------------------------
     |            |            |            |             |           |
kubemaster-1  kubemaster-2  kubemaster-3  kubeworker-1  kubeworker-2  nfs
192.168.30.240 .241         .242          .243          .244          .235
     |            |            |            |             |           |
     -----------------------------------------------------------------
                         Kubernetes API VIP
                          192.168.30.250

                         kube-vip LB Pool
                     192.168.30.200-192.168.30.219

                         Traefik API Gateway
                          192.168.30.200


                  Isolated Storage Network
                      192.168.32.0/24
                              vmbr2
                                |
     -----------------------------------------------------------------
     |            |            |            |             |           |
kubemaster-1  kubemaster-2  kubemaster-3  kubeworker-1  kubeworker-2  nfs
192.168.32.11 .12          .13           .21           .22           .10
                                                                    |
                                                            /srv/nfs/k8s
```

### Firewall and Access Model

OPNsense provides the network boundary for the lab.

The management subnet is private and is not intended to be exposed directly to the public Internet. Remote administrative access is provided through WireGuard VPN on OPNsense.

The intended access model is:

| Traffic                                    | Access Model                          |
| ------------------------------------------ | ------------------------------------- |
| SSH to VMs                                 | Private management network / VPN only |
| Kubernetes API                             | Private management network / VPN only |
| Headlamp dashboard                         | Private management network / VPN only |
| Traefik application access                 | Private management network / VPN only |
| NFS storage traffic                        | Isolated storage network only         |
| Direct public Internet to Kubernetes nodes | Not allowed intentionally             |

The storage network does not have a default gateway on the Kubernetes nodes or NFS server storage interfaces. This prevents the storage subnet from being used as a general-purpose routed network.

### Storage Network Validation

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

Additional useful validation commands:

```bash
ip addr
ip route
ping -c 3 192.168.32.10
showmount -e 192.168.32.10
```

On the NFS server:

```bash
sudo exportfs -v
sudo ss -tulpn | grep 2049
```

## Task 1.3 — System-Level Configuration

### Kernel Modules

The following kernel modules were configured on the Kubernetes nodes:

```text
overlay
br_netfilter
```

These are required for container overlay filesystems and Kubernetes network packet handling through Linux bridges.

Example configuration file:

```text
/etc/modules-load.d/k8s.conf
```

Expected content:

```text
overlay
br_netfilter
```

Verification commands:

```bash
lsmod | grep overlay
lsmod | grep br_netfilter
```

### Sysctl Configuration

The following sysctl settings were applied:

```text
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
```

These settings allow bridged IPv4/IPv6 traffic to be processed correctly by iptables and allow forwarding required by Kubernetes networking.

Example configuration file:

```text
/etc/sysctl.d/k8s.conf
```

Expected content:

```text
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
```

Verification commands:

```bash
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
```

### Swap Disabled

Swap was disabled on all Kubernetes nodes.

Verification command:

```bash
swapon --show
```

Expected result:

```text
No output
```

Swap must remain disabled for kubelet stability and predictable Kubernetes scheduling behavior.

### Container Runtime

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

### Kubernetes Packages

The following packages were installed on all Kubernetes nodes:

```text
kubeadm
kubelet
kubectl
```

The packages were marked on hold to avoid accidental version drift:

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

Verification command:

```bash
apt-mark showhold
```

Expected held packages:

```text
kubeadm
kubectl
kubelet
```

### NFS Client Package

The NFS client package was installed on all Kubernetes nodes:

```text
nfs-common
```

This is required because the actual NFS mount happens on the Kubernetes node where a pod using an NFS-backed PVC is scheduled.

The NFS server VM uses:

```text
nfs-kernel-server
```

### Administrative User and Permissions

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

### SSH Security

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

## Verification Script

Phase 1 validation can be repeated with:

```bash
bash scripts/verify-phase1.sh
```

This script is used to check the baseline infrastructure and host configuration before moving on to Kubernetes cluster deployment.

## Phase 1 Completion Checklist

| Requirement                                                                              | Status   |
| ---------------------------------------------------------------------------------------- | -------- |
| Multiple KVM virtual machines provisioned                                                | Complete |
| Linux OS installed on VMs                                                                | Complete |
| Control-plane roles assigned                                                             | Complete |
| Worker node roles assigned                                                               | Complete |
| Dedicated storage server role assigned                                                   | Complete |
| Load-balancer role implemented through Kubernetes-native kube-vip and Traefik components | Complete |
| Linux distribution justified                                                             | Complete |
| KVM/Proxmox networking configured                                                        | Complete |
| Static IP addressing configured                                                          | Complete |
| Isolated storage network implemented                                                     | Complete |
| Multi-NIC layout implemented                                                             | Complete |
| Network topology documented                                                              | Complete |
| Kernel modules configured                                                                | Complete |
| Sysctl tuning applied                                                                    | Complete |
| Swap disabled                                                                            | Complete |
| Production-grade container runtime installed                                             | Complete |
| SSH key-based authentication enforced                                                    | Complete |
| Password SSH login disabled                                                              | Complete |
| Root SSH login disabled                                                                  | Complete |
| Dedicated sudo user configured                                                           | Complete |
| Private management/VPN access model documented                                           | Complete |
| Single-host lab HA limitation documented                                                 | Complete |

## Phase 1 Design Summary

Phase 1 establishes the infrastructure foundation for the Kubernetes cluster.

The design separates major responsibilities across dedicated VMs:

* Control-plane nodes manage the Kubernetes API and cluster state.
* Worker nodes run application workloads.
* A dedicated NFS VM provides persistent storage.
* OPNsense handles private routing, firewalling, and VPN access.
* kube-vip provides the Kubernetes API virtual IP.
* kube-vip service LoadBalancer support provides private application LoadBalancer IPs.
* Traefik provides the in-cluster API gateway for HTTP application routing.

The network design separates management and storage traffic using different Proxmox bridges and subnets. This keeps NFS persistent-volume traffic isolated from SSH, Kubernetes API, dashboard, and private application access traffic.

The system-level configuration prepares the VMs for Kubernetes by enabling required kernel modules, sysctl values, container runtime settings, package holds, and swap configuration.

SSH access is hardened across all VMs using key-only login and a dedicated sudo user.

The main limitation of this lab design is that all VMs run on one physical Proxmox host. The cluster demonstrates Kubernetes-level high availability, storage persistence, network separation, and secure private access patterns, but it does not provide physical-host fault tolerance. In production, these roles would be distributed across multiple hypervisor hosts or availability zones.
