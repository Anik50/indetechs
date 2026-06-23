# Traefik API Gateway

Traefik is deployed inside Kubernetes as the cluster ingress/API gateway for application HTTP routing.

In this environment, OPNsense provides the network edge, firewalling, and VPN access into the private management subnet. kube-vip provides Kubernetes `LoadBalancer` service IPs on the management network. Traefik receives one of those LoadBalancer IPs and routes application traffic to Kubernetes services.

## Exposure

Traefik is exposed using a Kubernetes `LoadBalancer` service.

| Item                  | Value            |
| --------------------- | ---------------- |
| LoadBalancer provider | kube-vip         |
| Traefik namespace     | `traefik`        |
| Traefik external IP   | `192.168.30.200` |
| HTTP port             | `80`             |
| HTTPS port            | `443`            |
| IngressClass          | `traefik`        |

The Traefik LoadBalancer IP is assigned from the kube-vip service pool:

```text
192.168.30.200-192.168.30.219
```

Traefik is reachable only from the private management network/VPN path. It is not intentionally exposed directly to the public Internet.

## Routing Flow

```text
Admin / VPN Client
  -> Traefik LoadBalancer IP: 192.168.30.200
  -> Traefik Service
  -> Traefik Pod
  -> Kubernetes Ingress: ops-ingress
  -> ops-frontend Service
  -> frontend Pods
  -> ops-backend Service
  -> backend Pods
  -> ops-database Service
  -> PostgreSQL StatefulSet
```

Backend and database services remain internal `ClusterIP` services. They are not exposed directly outside the cluster.

## Design Decision and Trade-offs

Traefik was selected as the application API gateway because it is lightweight, Kubernetes-native, and works cleanly with Kubernetes Ingress resources. It can be exposed through the kube-vip LoadBalancer pool without adding a separate external HAProxy or NGINX VM.

This design keeps OPNsense focused on firewalling, VPN access, and network boundary control, while Traefik handles application-layer routing inside Kubernetes.

Gateway API is the newer Kubernetes direction for traffic management and would provide a more expressive model for future routing requirements. For this assessment, Traefik with Kubernetes Ingress was chosen because it is mature, simple to validate, and sufficient for routing traffic to the 3-tier application.

The trade-off is that the current lab deployment uses plain HTTP on the private management/VPN network. This is acceptable for the local assessment environment because access to the subnet is restricted through OPNsense and WireGuard VPN. In a stricter production deployment, TLS would be enabled.

## Validation

The Traefik service received an external IP from the kube-vip LoadBalancer pool:

```text
traefik   LoadBalancer   10.106.32.137   192.168.30.200   80:30579/TCP,443:31233/TCP
```

Before application routes were created, a request to Traefik returned:

```text
HTTP/1.1 404 Not Found
```

This was expected. It confirmed that the LoadBalancer IP was reachable and that traffic was arriving at Traefik successfully.

## Application Routing

The Phase 3 application uses an Ingress with:

```yaml
ingressClassName: traefik
```

The application hostname is:

```text
ops.indetechs.local
```

For local browser access, the client machine must resolve the hostname to the Traefik LoadBalancer IP:

```text
192.168.30.200 ops.indetechs.local
```

In the lab, this can be configured using the client machine's hosts file. In a production environment, this would be handled by internal DNS.

## Test Commands

Check Traefik pods and service:

```bash
kubectl -n traefik get pods -o wide
kubectl -n traefik get svc -o wide
```

Check the IngressClass:

```bash
kubectl get ingressclass
```

Check the application Ingress:

```bash
kubectl -n app-prod get ingress ops-ingress -o wide
kubectl -n app-prod describe ingress ops-ingress
```

Test Traefik directly:

```bash
curl -I http://192.168.30.200
```

Test the frontend route through Traefik:

```bash
curl -H 'Host: ops.indetechs.local' http://192.168.30.200/
```

Test the backend API route through Traefik:

```bash
curl -H 'Host: ops.indetechs.local' http://192.168.30.200/api/tasks
```

## TLS Future Improvement

The current lab deployment exposes Traefik over plain HTTP on the private management network only. This was kept intentionally simple for the mandatory assessment scope, which focuses on KVM infrastructure, Kubernetes cluster setup, persistent storage, NetworkPolicy isolation, application deployment, and working gateway exposure.

For a stricter production deployment, TLS would be added using a re-encryption model:

```text
Client / VPN
  -> HTTPS
  -> OPNsense reverse proxy / edge TLS termination
  -> HTTPS
  -> Traefik LoadBalancer IP: 192.168.30.200
  -> Kubernetes Ingress
  -> Application services
```

In this model, OPNsense would act as the edge TLS endpoint and network policy enforcement boundary. Traefik would continue to act as the Kubernetes-native API gateway inside the cluster.

The connection from OPNsense to Traefik would also use HTTPS, avoiding plain HTTP between the firewall and the Kubernetes gateway.

This was left as future work because TLS hardening belongs to the optional production hardening scope. The current implementation is still acceptable for the assessment because application access is restricted to the private management network and WireGuard VPN path.
