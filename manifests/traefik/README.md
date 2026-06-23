# Traefik API Gateway

Traefik is installed with Helm and exposed using kube-vip as a Kubernetes `LoadBalancer` service.

## External IP

```text
192.168.30.200
```

## Install command

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  -f manifests/traefik/traefik-values.yaml
```

## Expected validation before app Ingress exists

```bash
curl -I http://192.168.30.200
```

Expected response:

```text
HTTP/1.1 404 Not Found
```

That response means traffic is reaching Traefik successfully.
