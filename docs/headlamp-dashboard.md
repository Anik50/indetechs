# Headlamp Dashboard

## Overview

Headlamp was installed to provide a Kubernetes dashboard for visual operational access to the cluster.

## Namespace

```text
headlamp
```

## Service

Headlamp is exposed using a NodePort service.

Access URLs:

```text
http://192.168.30.240:30639
http://192.168.30.241:30639
http://192.168.30.242:30639
http://192.168.30.243:30639
http://192.168.30.244:30639
```

## Login Token

```bash
kubectl create token headlamp -n headlamp
```

## Observed Cluster Health

A Headlamp workload screenshot shows:

```text
Pods: 37 Running
Deployments: 5 Running
ReplicaSets: 7 Running
DaemonSets: 3 Running
StatefulSets: 0 Running
Jobs: 0 Running
CronJobs: 0 Running
```

Core platform components shown include:

- `canal`
- `kube-proxy`
- `coredns`
- `metrics-server`
- `csi-driver-nfs`
- `headlamp`

Screenshot:

```text
screenshots/headlamp-workloads.png
```

## Production Note

For a real production environment, Headlamp should be placed behind a VPN, authenticated reverse proxy, or private gateway. RBAC should follow least privilege instead of broad cluster-admin access.
