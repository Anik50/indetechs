# Phase 2 — Kubernetes Cluster Setup

## Overview

Phase 2 is complete.

The Kubernetes cluster has been initialized successfully, all control-plane and worker nodes have joined the cluster, Canal CNI is installed, persistent storage using a dedicated NFS VM and NFS CSI driver is working, and cluster-level networking/security controls have been created.

The Phase 2 NetworkPolicies and Pod Disruption Budgets were created before the application deployment and were validated during Phase 3 after the frontend, backend, and database pods were deployed with the expected labels.

## Task 2.1 — Initialise the Cluster

### Requirement: Initialise the Control Plane Node

| Item                                                | Status   |
| --------------------------------------------------- | -------- |
| First control-plane node initialized with `kubeadm` | Complete |
| Kubernetes API endpoint configured through VIP      | Complete |
| Kubernetes API VIP configured with `kube-vip`       | Complete |
| Pod CIDR configured                                 | Complete |
| Service CIDR configured                             | Complete |
| Admin kubeconfig configured                         | Complete |

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

| Item                         | Status   |
| ---------------------------- | -------- |
| API server reachable         | Complete |
| kube-vip API VIP running     | Complete |
| CoreDNS running              | Complete |
| Canal running                | Complete |
| kube-proxy running           | Complete |
| Nodes Ready                  | Complete |
| Metrics Server installed     | Complete |
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

All nodes are running Ubuntu Server 24.04.4 LTS with kernel `6.8.0-124-generic` and container runtime `containerd://2.3.2`.

## Task 2.2 — Join the Worker Nodes

Both worker nodes were successfully joined to the Kubernetes cluster and reached the `Ready` state.

| Node           | Status | Role   | Internal IP      |
| -------------- | ------ | ------ | ---------------- |
| `kubeworker-1` | Ready  | worker | `192.168.30.243` |
| `kubeworker-2` | Ready  | worker | `192.168.30.244` |

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

| Component               | Value             |
| ----------------------- | ----------------- |
| Storage VM              | `nfs`             |
| Management IP           | `192.168.30.235`  |
| Storage IP              | `192.168.32.10`   |
| Export path             | `/srv/nfs/k8s`    |
| Storage network         | `192.168.32.0/24` |
| Kubernetes StorageClass | `nfs-csi`         |
| CSI driver              | `nfs.csi.k8s.io`  |
| Reclaim policy          | `Retain`          |
| Access mode tested      | `ReadWriteMany`   |

### Storage Justification

NFS was selected because it is lightweight, simple to operate, and suitable for the available local lab resources. It provides shared `ReadWriteMany` storage that can be mounted by pods across multiple Kubernetes nodes.

A distributed storage backend such as Longhorn or Rook/Ceph would provide stronger redundancy, but it would also require more CPU, memory, and disk resources. Given the 16 GB RAM constraint on the physical host, NFS provides a practical balance between functionality and resource usage.

To improve isolation, NFS traffic uses a dedicated storage network on `192.168.32.0/24`, separate from the management network.

### Performance and Redundancy Considerations

Performance:

* NFS traffic is separated onto a dedicated storage subnet.
* Kubernetes nodes access NFS through the isolated `vmbr2` bridge.
* The NFS server is simple and low overhead for a local KVM environment.
* NFS provides shared storage that can be consumed by pods scheduled on different Kubernetes nodes.

Redundancy:

* This implementation uses a single NFS server, so it is not fully redundant.
* The StorageClass uses `Retain` to reduce the risk of accidental data loss when PVCs are deleted.
* VM-level backups/snapshots are available through Proxmox.
* In a production environment, this would be improved with replicated NFS, DRBD, Longhorn, Rook/Ceph, or storage-level replication/backups.

### NFS Export

```text
/srv/nfs/k8s 192.168.32.0/24(rw,sync,no_subtree_check,no_root_squash)
```

The lab export currently uses `no_root_squash` to avoid UID/GID permission issues during CSI dynamic provisioning. In a stricter production deployment, this would be reviewed and replaced with tighter export permissions, `root_squash` where compatible, and workload-specific security contexts.

### StorageClass

StorageClass:

```text
nfs-csi
```

The NFS CSI StorageClass is configured as the default StorageClass for dynamic provisioning.

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

In this lab, storage isolation is primarily provided by:

* a dedicated Proxmox bridge for storage traffic,
* separate VM storage interfaces,
* no default gateway on the storage interface,
* NFS export restrictions to the storage subnet.

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

Application workloads also define resource requests and limits in their manifests. The namespace `LimitRange` provides an additional safety net so that pods do not run without resource defaults.

### Network Policies

NetworkPolicies were implemented to enforce 3-tier application isolation.

The security model is:

```text
traefik -> frontend    allowed on TCP 8080
frontend -> backend    allowed on TCP 8080
backend  -> database   allowed on TCP 5432
frontend -> database   blocked
all other app traffic  denied by default
DNS egress             allowed
```

Created NetworkPolicies:

```text
default-deny-ingress-egress
allow-dns-egress
allow-frontend-to-backend
allow-frontend-egress-to-backend
allow-backend-to-database
allow-backend-egress-to-database
allow-traefik-to-frontend
```

The Traefik-to-frontend policy is added with the Phase 3 workload manifests because it depends on the Traefik namespace and frontend labels. Backend and database services remain internal `ClusterIP` services and are not exposed directly outside the cluster.

Verification:

```bash
kubectl get networkpolicy -n app-prod
kubectl describe networkpolicy -n app-prod
kubectl -n app-prod get pods --show-labels
```

Expected result:

```text
NetworkPolicies exist in app-prod.
Application pods have labels matching the policy selectors.
Traefik can reach the frontend service.
Frontend can reach the backend service.
Backend can reach the database service.
Direct frontend-to-database traffic is blocked by policy design.
```

### Pod Disruption Budgets

Pod Disruption Budgets were created for the application tiers:

```text
frontend-pdb
backend-pdb
database-pdb
```

These PDBs are intended to maintain application availability during voluntary disruptions such as node drains or maintenance operations.

The frontend and backend PDBs help ensure that at least one replica remains available during voluntary disruption when multiple replicas are running.

The database PDB protects the single PostgreSQL pod from voluntary eviction. However, the database tier is still not highly available because it runs as a single PostgreSQL replica. The database data is persistent through the NFS-backed PVC, but the database service itself is not replicated.

Verification:

```bash
kubectl get pdb -n app-prod
kubectl describe pdb -n app-prod
```

Expected result after Phase 3 deployment:

```text
frontend-pdb, backend-pdb, and database-pdb exist.
The PDB selectors match the deployed application pods.
Voluntary disruptions are constrained according to the configured PDB rules.
```

### Manifest File

The Phase 2.4 security resources are stored in:

```text
manifests/security/cluster-security.yaml
```

This file contains namespace-level resource controls, NetworkPolicies, and Pod Disruption Budgets for the production application namespace.

The Phase 3 Traefik-to-frontend NetworkPolicy is stored with the workload manifests:

```text
manifests/workloads/networkpolicy-allow-traefik.yaml
```

## kube-vip LoadBalancer Support

During Phase 2, kube-vip was used for Kubernetes API high availability through the API VIP:

```text
192.168.30.250
```

During Phase 3, kube-vip service LoadBalancer support was added using a separate kube-vip services DaemonSet and the kube-vip cloud provider.

The LoadBalancer IP pool is now active:

```text
192.168.30.200-192.168.30.219
```

Traefik is exposed through the first assigned address:

```text
192.168.30.200
```

This means kube-vip now provides two separate networking functions in the cluster:

| Purpose                   | IP / Range                      | Implementation                                        |
| ------------------------- | ------------------------------- | ----------------------------------------------------- |
| Kubernetes API HA         | `192.168.30.250`                | kube-vip static pods                                  |
| Service LoadBalancer VIPs | `192.168.30.200-192.168.30.219` | kube-vip services DaemonSet + kube-vip cloud provider |

Verification commands:

```bash
kubectl -n kube-system get pods -o wide | grep kube-vip
kubectl -n kube-system get configmap kubevip -o yaml
kubectl get svc -A | grep LoadBalancer
kubectl -n traefik get svc -o wide
```

Expected result:

```text
kube-vip components are running.
The kubevip ConfigMap contains the LoadBalancer pool.
Traefik has an external LoadBalancer IP of 192.168.30.200.
```

## Phase 2 Verification Script

Phase 2 validation can be repeated with:

```bash
bash scripts/verify-phase2.sh
```

This script verifies the cluster foundation, node readiness, storage provisioning, and baseline Kubernetes platform components.

## Phase 2 Completion Checklist

| Requirement                                                                     | Status                                               |
| ------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Initialise control-plane node                                                   | Complete                                             |
| Configure Kubernetes API VIP                                                    | Complete                                             |
| Configure pod CIDR                                                              | Complete                                             |
| Configure service CIDR                                                          | Complete                                             |
| Install CNI plugin                                                              | Complete                                             |
| Justify CNI choice                                                              | Complete                                             |
| Verify API server health                                                        | Complete                                             |
| Verify cluster components                                                       | Complete                                             |
| Join worker nodes                                                               | Complete                                             |
| Confirm worker nodes Ready                                                      | Complete                                             |
| Apply worker node labels                                                        | Complete                                             |
| Set up dedicated NFS storage VM                                                 | Complete                                             |
| Configure NFS export                                                            | Complete                                             |
| Configure storage network                                                       | Complete                                             |
| Install NFS CSI driver                                                          | Complete                                             |
| Create NFS StorageClass                                                         | Complete                                             |
| Test PVC dynamic provisioning                                                   | Complete                                             |
| Test pod volume mount                                                           | Complete                                             |
| Justify NFS on performance grounds                                              | Complete                                             |
| Justify NFS on redundancy grounds                                               | Complete with limitation noted                       |
| Configure access restrictions for NFS                                           | Complete through network isolation and export subnet |
| Enforce NetworkPolicies                                                         | Complete                                             |
| Block direct frontend-to-database traffic                                       | Complete by policy design                            |
| Use namespaces for environment separation                                       | Complete                                             |
| Set resource requests/limits on application pods and enforce namespace defaults | Complete                                             |
| Configure Pod Disruption Budgets                                                | Complete                                             |
| Validate PDBs and NetworkPolicies with Phase 3 workloads                        | Complete                                             |
| Extend kube-vip for service LoadBalancer IPs                                    | Complete during Phase 3                              |

## Phase 2 Design Summary

The Kubernetes cluster foundation is operational. The control plane was initialized with `kubeadm`, additional control-plane and worker nodes joined successfully, and all nodes reached the `Ready` state. Canal was installed as the CNI plugin, and the Kubernetes API is reachable through the kube-vip virtual IP.

Persistent storage is implemented using a dedicated NFS server and the NFS CSI driver. This allows Kubernetes PersistentVolumeClaims to be dynamically provisioned and mounted by pods across the cluster. NFS was selected for this lab because it is lightweight and practical for the available hardware, while its single-server redundancy limitation is clearly documented.

Cluster-level security controls are implemented using namespace separation, ResourceQuota, LimitRange, NetworkPolicies, and Pod Disruption Budgets. The NetworkPolicies enforce the intended 3-tier application model where Traefik can reach the frontend, frontend traffic can reach the backend, backend traffic can reach the database, and direct frontend-to-database traffic is blocked.

kube-vip is used for both Kubernetes API high availability and private LoadBalancer service IPs. The API VIP is `192.168.30.250`, and the application LoadBalancer pool is `192.168.30.200-192.168.30.219`. Traefik uses `192.168.30.200` as the in-cluster API gateway entry point for the Phase 3 application.
