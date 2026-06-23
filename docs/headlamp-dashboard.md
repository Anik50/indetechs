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

## Access Control / Production Note

Headlamp is not exposed directly to the public Internet. It is exposed only on the private management subnet:

```text
192.168.30.0/24
```

Remote administrative access to this subnet is provided through the WireGuard VPN configured on OPNsense. This means dashboard access is protected by the OPNsense firewall boundary and requires VPN access before the Headlamp NodePort can be reached.

The current lab setup uses a Headlamp service account token for authentication. For a stricter production deployment, RBAC should be reduced from broad cluster-admin access to least-privilege roles, and Headlamp could additionally be placed behind an authenticated HTTPS reverse proxy.
