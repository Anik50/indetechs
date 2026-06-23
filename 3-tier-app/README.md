# Operations Task 3-Tier Application

This is the Phase 3 demonstration application for the production-grade Kubernetes cluster assessment.

## Tiers

| Tier | Technology | Purpose |
|---|---|---|
| Frontend | Nginx unprivileged + static HTML/JS | User interface and reverse proxy to backend |
| Backend | Node.js Express | REST API and database access |
| Database | PostgreSQL | Persistent application data |

## Runtime flow

```text
User/VPN
  -> 192.168.30.200
  -> Traefik LoadBalancer
  -> ops-frontend service
  -> ops-backend service
  -> ops-database service
  -> NFS-backed PostgreSQL PVC
```

## Local image build

From the repository root:

```bash
IMAGE_REGISTRY=docker.io/anik50 TAG=v1 bash scripts/build-push-phase3-images.sh
```

## Kubernetes deployment

```bash
bash scripts/create-phase3-secret.sh
kubectl apply -k manifests/workloads
bash scripts/verify-phase3.sh
```

Test through Traefik:

```bash
curl -H 'Host: ops.indetechs.local' http://192.168.30.200/
curl -H 'Host: ops.indetechs.local' http://192.168.30.200/api/tasks
```
