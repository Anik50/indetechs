# Traefik API Gateway

Traefik is deployed inside Kubernetes as the cluster ingress/API gateway.

## Exposure

Traefik is exposed using a Kubernetes `LoadBalancer` service.

- LoadBalancer provider: kube-vip
- Traefik external IP: `192.168.30.200`
- HTTP port: `80`
- HTTPS port: `443`
- IngressClass: `traefik`

## Validation

The service received an external IP from the kube-vip LoadBalancer pool:

```text
traefik   LoadBalancer   10.106.32.137   192.168.30.200   80:30579/TCP,443:31233/TCP
```

A request to Traefik returned:

```text
HTTP/1.1 404 Not Found
```

This is expected before application routes are created. It confirms that the LoadBalancer IP is reachable and traffic is arriving at Traefik.

## Application routing

The Phase 3 application uses an Ingress with:

```yaml
ingressClassName: traefik
```

Test command:

```bash
curl -H 'Host: todo.indetechs.local' http://192.168.30.200/
```
