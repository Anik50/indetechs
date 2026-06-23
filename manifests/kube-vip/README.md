# kube-vip LoadBalancer Manifests

These files document the working kube-vip LoadBalancer configuration used for Phase 3.

## Important separation

The cluster uses kube-vip for two separate jobs:

1. Existing static pods provide the control-plane API VIP: `192.168.30.250`
2. The added DaemonSet provides service LoadBalancer advertisement for app VIPs

Do not replace or edit the existing static pod manifest at `/etc/kubernetes/manifests/kube-vip.yaml` just to deploy application LoadBalancers.

## Files

| File | Purpose |
|---|---|
| `kube-vip-services-ds.yaml` | Service-only kube-vip DaemonSet using ARP mode |
| `kubevip-ip-pool.yaml` | IP pool for kube-vip cloud provider |

## Correct subnet value

The service DaemonSet must use:

```yaml
vip_subnet: /32
```

Using `32` caused kube-vip to parse service VIPs incorrectly as `192.168.30.20032`.
