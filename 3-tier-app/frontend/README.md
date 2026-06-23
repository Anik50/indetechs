# Frontend Tier

The frontend is a small static UI served by `nginxinc/nginx-unprivileged` on port `8080`.

## Features

- Runs as a non-root user
- Uses a minimal Nginx image
- Has an HTTP health endpoint at `/healthz`
- Proxies `/api/*` requests to the backend Kubernetes service

## Build

```bash
docker build -t docker.io/anik50/indetechs-ops-frontend:v1 3-tier-app/frontend
```
