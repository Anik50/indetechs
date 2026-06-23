# kube-vip LoadBalancer Configuration

This cluster uses kube-vip for two separate HA networking functions:

1. Control-plane API VIP
2. Kubernetes Service LoadBalancer VIPs

## Control-plane VIP

The original kube-vip static pods provide the Kubernetes API virtual IP:

- API VIP: `192.168.30.250`
- Interface: `ens18`
- Mode: ARP
- Purpose: highly available Kubernetes API endpoint

This static pod configuration was left unchanged.

## Service LoadBalancer VIPs

A separate kube-vip DaemonSet named `kube-vip-services` was deployed in the `kube-system` namespace.

This DaemonSet is configured for service advertisement only:

- `cp_enable=false`
- `svc_enable=true`
- `vip_arp=true`
- `vip_interface=ens18`
- `vip_subnet=/32`
- `svc_election=true`

The `/32` value is required so kube-vip formats service VIPs correctly, for example:

```text
192.168.30.200/32
```

Using `32` caused kube-vip to parse the address incorrectly as:

```text
192.168.30.20032
```

## kube-vip Cloud Provider

The kube-vip cloud provider is installed in `kube-system`.

It assigns `LoadBalancer` service IPs from the following pool:

```text
192.168.30.200-192.168.30.219
```

This pool is stored in the `kubevip` ConfigMap:

```yaml
data:
  range-global: 192.168.30.200-192.168.30.219
```

## Validation

A temporary nginx service was exposed as a Kubernetes `LoadBalancer`.

Result:

```text
nginx-lb   LoadBalancer   192.168.30.200
```

Connectivity test:

```text
curl -I http://192.168.30.200
HTTP/1.1 200 OK
```

This confirms that kube-vip cloud provider IP assignment and kube-vip service advertisement are working.
