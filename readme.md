# Indetechs Kubernetes Technical Assessment

## Project

This repository documents and stores manifests for a local production-style Kubernetes environment built on KVM virtual machines for the Indetechs Software Limited IT Operations Officer technical assessment.

The environment is deployed on Proxmox VE using KVM/QEMU virtual machines. OPNsense provides routing/firewall functionality and WireGuard VPN access into the private management subnet. Kubernetes is deployed using `kubeadm` with three control-plane nodes, two worker nodes, a dedicated NFS storage VM, Canal CNI, kube-vip for the Kubernetes API virtual IP, Metrics Server, Headlamp, and NFS CSI dynamic storage provisioning.

## Current Progress

| Phase | Scope | Status |
|---|---|---|
| Phase 1 | KVM infrastructure setup | Complete |
| Phase 2 | Kubernetes cluster setup, storage, networking/security controls | Complete |
| Phase 3 | 3-tier application deployment | Pending |
| Phase 4+ | Optional automation, observability, DR, CI/CD, testing | Pending / Future work |

## High-Level Architecture

```text
                         Internet / Upstream
                                |
                              vmbr0
                                |
                            OPNsense
                                |
                  Private Management Network
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

## VM Inventory

| VM | Management IP | Storage IP | Role |
|---|---:|---:|---|
| `kubemaster-1` | `192.168.30.240` | `192.168.32.11` | Kubernetes control plane |
| `kubemaster-2` | `192.168.30.241` | `192.168.32.12` | Kubernetes control plane |
| `kubemaster-3` | `192.168.30.242` | `192.168.32.13` | Kubernetes control plane |
| `kubeworker-1` | `192.168.30.243` | `192.168.32.21` | Kubernetes worker |
| `kubeworker-2` | `192.168.30.244` | `192.168.32.22` | Kubernetes worker |
| `nfs` | `192.168.30.235` | `192.168.32.10` | Dedicated NFS storage server |
| `opnsense` | Environment-specific | N/A | Router/firewall |

## Cluster Summary

| Component | Value |
|---|---|
| Kubernetes version | `v1.36.2` |
| OS | Ubuntu Server 24.04.4 LTS |
| Kernel | `6.8.0-124-generic` |
| Container runtime | `containerd://2.3.2` |
| CNI | Canal |
| Pod CIDR | `10.244.0.0/16` |
| Service CIDR | `10.96.0.0/12` |
| Kubernetes API VIP | `192.168.30.250` |
| Storage backend | NFS + NFS CSI |
| Default StorageClass | `nfs-csi` |
| Dashboard | Headlamp |
| Metrics | Metrics Server |

## Repository Structure

```text
.
├── README.md
├── docs/
│   ├── phase-1-infrastructure.md
│   ├── phase-2-kubernetes-cluster.md
│   ├── network-topology.md
│   ├── storage-design.md
│   ├── security-hardening.md
│   └── headlamp-dashboard.md
├── manifests/
│   ├── namespaces/
│   │   └── app-namespaces.yaml
│   ├── security/
│   │   └── cluster-security.yaml
│   ├── storage/
│   │   ├── nfs-storageclass.yaml
│   │   └── nfs-pvc-test.yaml
│   ├── workloads/
│   │   └── .gitkeep
│   └── pdb/
│       └── .gitkeep
├── scripts/
│   ├── verify-phase1.sh
│   └── verify-phase2.sh
└── screenshots/
    └── headlamp-workloads.png
```

## Phase Documentation

- [Phase 1 — KVM Infrastructure Setup](docs/phase-1-infrastructure.md)
- [Phase 2 — Kubernetes Cluster Setup](docs/phase-2-kubernetes-cluster.md)
- [Network Topology](docs/network-topology.md)
- [Storage Design](docs/storage-design.md)
- [Security Hardening](docs/security-hardening.md)
- [Headlamp Dashboard](docs/headlamp-dashboard.md)

## Main Manifests

| Manifest | Purpose |
|---|---|
| `manifests/storage/nfs-storageclass.yaml` | NFS CSI StorageClass |
| `manifests/storage/nfs-pvc-test.yaml` | NFS dynamic provisioning test |
| `manifests/namespaces/app-namespaces.yaml` | App environment namespaces |
| `manifests/security/cluster-security.yaml` | LimitRange, ResourceQuota, NetworkPolicies, PDBs |

## Quick Verification

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get storageclass,pv,pvc -A
kubectl get limitrange,resourcequota,networkpolicy,pdb -n app-prod
kubectl top nodes
```

## Notes

The kube-vip cloud provider for Kubernetes `Service` objects of type `LoadBalancer` has not been installed yet. kube-vip is currently used for Kubernetes API high availability through the API VIP `192.168.30.250`. Application `LoadBalancer` service support is planned for the application exposure phase.

The Phase 2 NetworkPolicies and Pod Disruption Budgets are created in advance for the future 3-tier application. Their runtime behavior will be validated in Phase 3 after deploying frontend, backend, and database pods using the expected labels.
