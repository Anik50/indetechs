# Storage Design

## Selected Storage Backend

Selected option:

```text
Option A — NFS-based persistent storage
```

## Components

| Component | Value |
|---|---|
| NFS VM | `nfs` |
| Management IP | `192.168.30.235` |
| Storage IP | `192.168.32.10` |
| Export path | `/srv/nfs/k8s` |
| Allowed subnet | `192.168.32.0/24` |
| Kubernetes CSI driver | `nfs.csi.k8s.io` |
| StorageClass | `nfs-csi` |
| ReclaimPolicy | `Retain` |
| Access mode tested | `ReadWriteMany` |

## NFS Export

```text
/srv/nfs/k8s 192.168.32.0/24(rw,sync,no_subtree_check,no_root_squash)
```

## Why NFS

NFS was selected because it is lightweight, easy to operate, and fits the available hardware. The lab host has 16 GB RAM, so a distributed storage platform such as Rook/Ceph would add significant memory and operational overhead.

NFS provides shared `ReadWriteMany` storage, which is useful for Kubernetes workloads that need shared persistent volumes.

## Performance Considerations

- NFS traffic uses the isolated `192.168.32.0/24` storage network.
- Kubernetes nodes access NFS through the Proxmox `vmbr2` storage bridge.
- Storage traffic is separated from SSH, API, dashboard, and application access traffic.

## Redundancy Considerations

The current design uses a single NFS VM, so it is not fully redundant. This limitation is documented intentionally.

Mitigations and future improvements:

- `Retain` reclaim policy is used to reduce accidental data loss.
- Proxmox VM backups/snapshots can be used for recovery.
- A production design could use replicated NFS, DRBD, Longhorn, Rook/Ceph, or enterprise storage.

## Kubernetes Integration

The NFS CSI driver is installed in `kube-system`. It provides dynamic provisioning through the `nfs-csi` StorageClass.

Verification commands:

```bash
kubectl get pods -n kube-system | grep csi-nfs
kubectl get csidrivers
kubectl get storageclass
kubectl get pv
kubectl get pvc -A
```

## Test PVC

The test manifest is stored at:

```text
manifests/storage/nfs-pvc-test.yaml
```

Verification:

```bash
kubectl apply -f manifests/storage/nfs-pvc-test.yaml
kubectl get pvc -n storage-test
kubectl get pv
kubectl get pod -n storage-test -o wide
kubectl exec -n storage-test nfs-test-pod -- cat /data/test.txt
```
