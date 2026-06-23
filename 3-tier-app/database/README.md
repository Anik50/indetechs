# Database Tier

The database tier uses PostgreSQL with an initialization script and a Kubernetes PVC backed by the existing `nfs-csi` StorageClass.

## Build

```bash
docker build -t docker.io/anik50/indetechs-todo-database:v1 apps/todo-3tier/database
```

## Persistence

The StatefulSet requests a `2Gi` PVC using the default NFS CSI storage backend:

```yaml
storageClassName: nfs-csi
```

This satisfies the Phase 3 persistent storage requirement.
