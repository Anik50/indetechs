# Backend Tier

The backend is a lightweight Node.js Express API listening on port `8080`.

## Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/healthz` | GET | Container liveness |
| `/readyz` | GET | Database-backed readiness check |
| `/api/todos` | GET | List todos |
| `/api/todos` | POST | Create todo |
| `/api/todos/:id` | PATCH | Update completion state |
| `/api/todos/:id` | DELETE | Delete todo |

## Build

```bash
docker build -t docker.io/anik50/indetechs-todo-backend:v1 apps/todo-3tier/backend
```
