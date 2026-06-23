# Phase 3 Workload Manifests

These manifests deploy the 3-tier Todo application into the existing `app-prod` namespace.

## Required existing resources

These already exist from Phase 2:

- `app-prod` namespace
- `nfs-csi` StorageClass
- ResourceQuota and LimitRange in `app-prod`
- baseline NetworkPolicies in `app-prod`
- Traefik IngressClass named `traefik`

## Secret creation

Before applying the kustomization, create the database secret:

```bash
bash scripts/create-phase3-secret.sh
```

## Deploy

```bash
kubectl apply -k manifests/workloads
```

## Verify

```bash
bash scripts/verify-phase3.sh
```

## Access

Use Traefik's kube-vip LoadBalancer IP:

```bash
curl -H 'Host: todo.indetechs.local' http://192.168.30.200/
```

Or add a local hosts entry on your admin workstation:

```text
192.168.30.200 todo.indetechs.local
```
