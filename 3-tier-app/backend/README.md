# Backend Tier

The backend is a lightweight Node.js Express API listening on port `8080`.

## Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/healthz` | GET | Container liveness |
| `/readyz` | GET | Database-backed readiness check |
| `/api/tasks` | GET | List tasks |
| `/api/tasks` | POST | Create task |
| `/api/tasks/:id` | PATCH | Update completion state |
| `/api/tasks/:id` | DELETE | Delete task |

## Build

```bash
docker build -t docker.io/anik50/indetechs-ops-backend:v1 3-tier-app/backend
```
