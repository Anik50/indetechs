# Phase 2 — Kubernetes Cluster Setup

## Overview

Phase 2 is complete.

The Kubernetes cluster has been initialized successfully, all control-plane and worker nodes have joined the cluster, Canal CNI is installed, persistent storage using a dedicated NFS VM and NFS CSI driver is working, and cluster-level networking/security controls have been created.

The Phase 2 NetworkPolicies and Pod Disruption Budgets are deployed in advance for the future 3-tier application. Their runtime behavior will be validated during Phase 3 after deploying frontend, backend, and database pods using the expected labels.

## Task 2.1 — Initialise the Cluster

### Requirement: Initialise the Control Plane Node

| Item | Status |
|---|---|
| First control-plane node initialized with `kubeadm` | Complete |
| Kubernetes API endpoint configured through VIP | Complete |
| Kubernetes API VIP configured with `kube-vip` | Complete |
| Pod CIDR configured | Complete |
| Service CIDR configured | Complete |
| Admin kubeconfig configured | Complete |

Cluster endpoint:

```text
192.168.30.250:6443
```

Pod CIDR:

```text
10.244.0.0/16
```

Service CIDR:

```text
10.96.0.0/12
```

Verification commands:

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
curl -k https://192.168.30.250:6443/version
```

Expected result:

```text
The Kubernetes API server is reachable through the VIP.
All control-plane components are running.
All nodes report Ready.
```

### CNI Plugin Selection and Justification

CNI selected:

```text
Canal
```

Canal was selected because it combines a simple overlay networking model with Kubernetes NetworkPolicy support. This makes it suitable for a kubeadm-based lab cluster where the goal is to keep networking operationally simple while still supporting security controls such as frontend/backend/database tier isolation.

Canal is also lightweight compared with more complex CNIs, which is appropriate for the available local hardware resources.

Verification commands:

```bash
kubectl get pods -n kube-system | grep canal
kubectl get pods -n kube-system | grep coredns
kubectl get nodes -o wide
```

### Cluster Health Verification

| Item | Status |
|---|---|
| API server reachable | Complete |
| kube-vip running | Complete |
| CoreDNS running | Complete |
| Canal running | Complete |
| kube-proxy running | Complete |
| Nodes Ready | Complete |
| Metrics Server installed | Complete |
| Headlamp dashboard available | Complete |

Verification commands:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get --raw='/readyz?verbose'
kubectl top nodes
kubectl top pods -A
```

Observed node state:

```text
NAME           STATUS   ROLES           VERSION   INTERNAL-IP
kubemaster-1   Ready    control-plane   v1.36.2   192.168.30.240
kubemaster-2   Ready    control-plane   v1.36.2   192.168.30.241
kubemaster-3   Ready    control-plane   v1.36.2   192.168.30.242
kubeworker-1   Ready    worker          v1.36.2   192.168.30.243
kubeworker-2   Ready    worker          v1.36.2   192.168.30.244
```

All nodes are running Ubuntu 24.04.4 LTS with kernel `6.8.0-124-generic` and container runtime `containerd://2.3.2`.

## Task 2.2 — Join the Worker Nodes

Both worker nodes were successfully joined to the Kubernetes cluster and reached the `Ready` state.

| Node | Status | Role | Internal IP |
|---|---|---|---|
| `kubeworker-1` | Ready | worker | `192.168.30.243` |
| `kubeworker-2` | Ready | worker | `192.168.30.244` |

The worker nodes were labeled to support advanced workload scheduling and storage-aware placement.

```bash
kubectl label node kubeworker-1 node-role.kubernetes.io/worker=worker --overwrite
kubectl label node kubeworker-2 node-role.kubernetes.io/worker=worker --overwrite
kubectl label node kubeworker-1 workload-role=application --overwrite
kubectl label node kubeworker-2 workload-role=application --overwrite
kubectl label node kubeworker-1 storage-client=nfs --overwrite
kubectl label node kubeworker-2 storage-client=nfs --overwrite
```

Verification:

```bash
kubectl get nodes
kubectl get nodes --show-labels
```

Result:

```text
kubeworker-1   Ready   worker
kubeworker-2   Ready   worker
```

Labels applied:

```text
node-role.kubernetes.io/worker=worker
workload-role=application
storage-client=nfs
```

The `workload-role=application` label allows application workloads to be scheduled specifically onto worker nodes. The `storage-client=nfs` label identifies nodes that are prepared to mount NFS-backed persistent volumes.

## Task 2.3 — Set Up Persistent Storage

### Selected Option

Selected option:

```text
Option A — NFS-based persistent storage
```

### NFS Storage Design

| Component | Value |
|---|---|
| Storage VM | `nfs` |
| Management IP | `192.168.30.235` |
| Storage IP | `192.168.32.10` |
| Export path | `/srv/nfs/k8s` |
| Storage network | `192.168.32.0/24` |
| Kubernetes StorageClass | `nfs-csi` |
| CSI driver | `nfs.csi.k8s.io` |
| Reclaim policy | `Retain` |
| Access mode tested | `ReadWriteMany` |

### Storage Justification

NFS was selected because it is lightweight, simple to operate, and suitable for the available local lab resources. It provides shared `ReadWriteMany` storage that can be mounted by pods across multiple Kubernetes nodes.

A distributed storage backend such as Longhorn or Rook/Ceph would provide stronger redundancy, but it would also require more CPU, memory, and disk resources. Given the 16 GB RAM constraint on the physical host, NFS provides a practical balance between functionality and resource usage.

To improve isolation, NFS traffic uses a dedicated storage network on `192.168.32.0/24`, separate from the management network.

### Performance and Redundancy Considerations

Performance:

- NFS traffic is separated onto a dedicated storage subnet.
- Kubernetes nodes access NFS through the isolated `vmbr2` bridge.
- The NFS server is simple and low overhead for a local KVM environment.

Redundancy:

- This implementation uses a single NFS server, so it is not fully redundant.
- The StorageClass uses `Retain` to reduce accidental data loss.
- VM-level backups/snapshots are available through Proxmox.
- In a production environment, this would be improved with replicated NFS, DRBD, Longhorn, Rook/Ceph, or storage-level replication/backups.

### NFS Export

```text
/srv/nfs/k8s 192.168.32.0/24(rw,sync,no_subtree_check,no_root_squash)
```

### StorageClass

```text
nfs-csi
```

Verification commands:

```bash
kubectl get storageclass
kubectl get pv
kubectl get pvc -A
kubectl get pods -n storage-test -o wide
kubectl exec -n storage-test nfs-test-pod -- cat /data/test.txt
```

Expected result:

```text
PVC is Bound.
PV is created dynamically.
Test pod mounts the PVC successfully.
Data is written to the NFS-backed volume.
```

### Firewall / Access Control Note

Storage access is restricted by network design and NFS export rules.

The NFS export only allows clients from:

```text
192.168.32.0/24
```

The storage network has no default gateway on the Kubernetes nodes, and it is isolated from the management network. This limits NFS access to nodes attached to the storage bridge.

## Task 2.4 — Cluster Networking and Security

Cluster-level workload security controls were implemented in the `app-prod` namespace.

### Namespace Separation

Separate namespaces were created for environment separation:

```bash
kubectl create namespace app-dev
kubectl create namespace app-staging
kubectl create namespace app-prod
```

The namespaces were labeled by environment:

```bash
kubectl label namespace app-dev environment=dev --overwrite
kubectl label namespace app-staging environment=staging --overwrite
kubectl label namespace app-prod environment=prod --overwrite
```

Verification:

```bash
kubectl get namespaces --show-labels | grep app-
```

Result:

```text
app-dev       Active   environment=dev
app-staging   Active   environment=staging
app-prod      Active   environment=prod
```

### Resource Management

A `LimitRange` was created in the `app-prod` namespace to apply default CPU and memory requests and limits to containers.

A `ResourceQuota` was also created to prevent the namespace from consuming unlimited cluster resources.

Configured quota:

```text
pods: 20
requests.cpu: 2
requests.memory: 2Gi
limits.cpu: 4
limits.memory: 4Gi
```

Verification:

```bash
kubectl get limitrange,resourcequota -n app-prod
```

Result:

```text
limitrange/default-resource-limits
resourcequota/app-prod-resource-quota
```

### Network Policies

NetworkPolicies were implemented to enforce 3-tier application isolation.

The security model is:

```text
frontend -> backend     allowed on TCP 8080
backend  -> database    allowed on TCP 5432
frontend -> database    blocked
all other app traffic   denied by default
DNS egress              allowed
```

Created NetworkPolicies:

```text
default-deny-ingress-egress
allow-dns-egress
allow-frontend-to-backend
allow-frontend-egress-to-backend
allow-backend-to-database
allow-backend-egress-to-database
```

Verification:

```bash
kubectl get networkpolicy -n app-prod
```

Result:

```text
allow-backend-egress-to-database
allow-backend-to-database
allow-dns-egress
allow-frontend-egress-to-backend
allow-frontend-to-backend
default-deny-ingress-egress
```

### Pod Disruption Budgets

Pod Disruption Budgets were created for the future application tiers:

```text
frontend-pdb
backend-pdb
database-pdb
```

These PDBs are intended to maintain application availability during voluntary disruptions such as node drains or maintenance operations.

Verification:

```bash
kubectl get pdb -n app-prod
```

Current note:

The PDBs currently show zero allowed disruptions because the frontend, backend, and database pods have not been deployed yet. Their behavior will be validated during Phase 3 after the 3-tier application is deployed with the matching labels.

### Manifest File

The Phase 2.4 security resources are stored in:

```text
manifests/security/cluster-security.yaml
```

This file contains namespace-level resource controls, NetworkPolicies, and Pod Disruption Budgets for the production application namespace.

## Phase 2 Completion Checklist

| Requirement | Status |
|---|---|
| Initialise control-plane node | Complete |
| Configure Kubernetes API VIP | Complete |
| Configure pod CIDR | Complete |
| Configure service CIDR | Complete |
| Install CNI plugin | Complete |
| Justify CNI choice | Complete |
| Verify API server health | Complete |
| Verify cluster components | Complete |
| Join worker nodes | Complete |
| Confirm worker nodes Ready | Complete |
| Apply worker node labels | Complete |
| Set up dedicated NFS storage VM | Complete |
| Configure NFS export | Complete |
| Configure storage network | Complete |
| Install NFS CSI driver | Complete |
| Create NFS StorageClass | Complete |
| Test PVC dynamic provisioning | Complete |
| Test pod volume mount | Complete |
| Justify NFS on performance grounds | Complete |
| Justify NFS on redundancy grounds | Complete with limitation noted |
| Configure access restrictions for NFS | Complete through network isolation and export subnet |
| Enforce NetworkPolicies | Complete |
| Block direct frontend-to-database traffic | Complete by policy design |
| Use namespaces for environment separation | Complete |
| Set resource requests/limits through namespace defaults | Complete |
| Configure Pod Disruption Budgets | Complete |

## Phase 2 Design Summary

The Kubernetes cluster foundation is operational. The control plane was initialized with `kubeadm`, additional control-plane and worker nodes joined successfully, and all nodes reached the Ready state. Canal was installed as the CNI plugin, and the Kubernetes API is reachable through the kube-vip virtual IP.

Persistent storage is implemented using a dedicated NFS server and the NFS CSI driver. This allows Kubernetes PersistentVolumeClaims to be dynamically provisioned and mounted by pods across the cluster.

Cluster-level security controls are implemented using namespace separation, ResourceQuota, LimitRange, NetworkPolicies, and Pod Disruption Budgets. The NetworkPolicies enforce the intended 3-tier application model where frontend traffic can reach the backend, backend traffic can reach the database, and direct frontend-to-database traffic is blocked.

The kube-vip cloud provider for application `LoadBalancer` services has not been installed yet. kube-vip is currently used for Kubernetes API high availability only. Application LoadBalancer support is planned for Phase 3 application exposure.
