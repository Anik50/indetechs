#!/usr/bin/env bash
set -euo pipefail

IMAGE_REGISTRY="${IMAGE_REGISTRY:-docker.io/anik50}"
TAG="${TAG:-v1}"

FRONTEND_IMAGE="${IMAGE_REGISTRY}/indetechs-todo-frontend:${TAG}"
BACKEND_IMAGE="${IMAGE_REGISTRY}/indetechs-todo-backend:${TAG}"
DATABASE_IMAGE="${IMAGE_REGISTRY}/indetechs-todo-database:${TAG}"

echo "Building Phase 3 images"
echo "Frontend: ${FRONTEND_IMAGE}"
echo "Backend:  ${BACKEND_IMAGE}"
echo "Database: ${DATABASE_IMAGE}"

docker build -t "${FRONTEND_IMAGE}" apps/todo-3tier/frontend
docker build -t "${BACKEND_IMAGE}" apps/todo-3tier/backend
docker build -t "${DATABASE_IMAGE}" apps/todo-3tier/database

echo "Pushing images"
docker push "${FRONTEND_IMAGE}"
docker push "${BACKEND_IMAGE}"
docker push "${DATABASE_IMAGE}"

echo "Done. If IMAGE_REGISTRY or TAG differ from defaults, update manifests/workloads/kustomization.yaml accordingly."
