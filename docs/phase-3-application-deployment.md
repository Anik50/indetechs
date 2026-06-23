# Phase 3: 3-Tier Application Deployment

This document covers the Phase 3 application deployed on the Kubernetes cluster.

## Objective

Deploy a production-style 3-tier application using:

- optimized container images
- Kubernetes Deployments and StatefulSets
- persistent database storage
- ConfigMaps and Secrets
- health checks
- rolling updates
- autoscaling
- NetworkPolicy segmentation
- Traefik API gateway exposure

## Application architecture

```text
Admin/VPN Client
  -> Traefik LoadBalancer: 192.168.30.200
  -> Ingress: todo.indetechs.local
  -> todo-frontend Service
  -> todo-backend Service
  -> todo-database Service
  -> PostgreSQL PVC using nfs-csi
```

## Components

| Component | Kubernetes object | Replicas | Port | Storage |
|---|---:|---:|---:|---|
| Frontend | Deployment | 2 | 8080 | None |
| Backend | Deployment | 2 | 8080 | None |
| Database | StatefulSet | 1 | 5432 | NFS CSI PVC |

## Container image strategy

The frontend and backend use multi-stage Dockerfiles. The containers are small, expose only the required ports, and run without privilege escalation.

The database image extends the official PostgreSQL Alpine image and includes a minimal initialization SQL file.

## Kubernetes namespace

The app runs in the existing production namespace:

```text
app-prod
```

This namespace already has ResourceQuota, LimitRange, PDBs, and NetworkPolicies from Phase 2.

## Configuration and secrets

Non-sensitive configuration is stored in:

```text
manifests/workloads/app-config.yaml
```

The database password is created as a Kubernetes Secret using:

```bash
bash scripts/create-phase3-secret.sh
```

The Secret is intentionally not committed as a static manifest with real credentials.

## Persistent storage

The PostgreSQL StatefulSet uses a PVC from the existing NFS CSI StorageClass:

```yaml
storageClassName: nfs-csi
```

The requested storage size is:

```text
2Gi
```

Validation commands:

```bash
kubectl -n app-prod get pvc
kubectl -n app-prod get pv
```

## Health checks

Frontend:

```text
GET /healthz
```

Backend:

```text
GET /healthz  # liveness
GET /readyz   # readiness, includes database check
```

Database:

```text
pg_isready
```

## Rolling update configuration

The frontend and backend Deployments use:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

This allows new pods to become ready before old pods are removed.

## Autoscaling

The frontend has an HPA:

```text
minReplicas: 2
maxReplicas: 4
CPU target: 70%
```

Metrics Server is required and was installed in Phase 2.

## NetworkPolicy

Existing Phase 2 policies allow:

```text
frontend -> backend: 8080
backend -> database: 5432
pods -> kube-dns: 53
```

Phase 3 adds one policy:

```text
traefik namespace -> frontend pods: 8080
```

This allows external traffic to enter only through Traefik.

## External access

Traefik is exposed at:

```text
192.168.30.200
```

The app route is:

```text
Host: todo.indetechs.local
```

Test without DNS:

```bash
curl -H 'Host: todo.indetechs.local' http://192.168.30.200/
curl -H 'Host: todo.indetechs.local' http://192.168.30.200/api/todos
```

## Deployment commands

```bash
IMAGE_REGISTRY=docker.io/anik50 TAG=v1 bash scripts/build-push-phase3-images.sh
bash scripts/create-phase3-secret.sh
kubectl apply -k manifests/workloads
bash scripts/verify-phase3.sh
```

## Persistence validation

Create a todo item:

```bash
curl -H 'Host: todo.indetechs.local' \
  -H 'Content-Type: application/json' \
  -d '{"title":"Persistence test"}' \
  http://192.168.30.200/api/todos
```

Restart the database pod:

```bash
kubectl -n app-prod delete pod -l app.kubernetes.io/component=database
kubectl -n app-prod rollout status statefulset/todo-database
```

Confirm the item still exists:

```bash
curl -H 'Host: todo.indetechs.local' http://192.168.30.200/api/todos
```

If the item remains, PostgreSQL data survived pod recreation through the NFS-backed PVC.
