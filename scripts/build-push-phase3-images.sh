#!/usr/bin/env bash
set -euo pipefail

IMAGE_REGISTRY="${IMAGE_REGISTRY:-docker.io/anik50}"
TAG="${TAG:-v1}"

FRONTEND_IMAGE="${IMAGE_REGISTRY}/indetechs-ops-frontend:${TAG}"
BACKEND_IMAGE="${IMAGE_REGISTRY}/indetechs-ops-backend:${TAG}"
DATABASE_IMAGE="${IMAGE_REGISTRY}/indetechs-ops-database:${TAG}"

echo "Building Phase 3 images"
echo "Frontend: ${FRONTEND_IMAGE}"
echo "Backend:  ${BACKEND_IMAGE}"
echo "Database: ${DATABASE_IMAGE}"

docker build -t "${FRONTEND_IMAGE}" 3-tier-app/frontend
docker build -t "${BACKEND_IMAGE}" 3-tier-app/backend
docker build -t "${DATABASE_IMAGE}" 3-tier-app/database

echo "Pushing images"
docker push "${FRONTEND_IMAGE}"
docker push "${BACKEND_IMAGE}"
docker push "${DATABASE_IMAGE}"

echo "Done. If IMAGE_REGISTRY or TAG differ from defaults, update manifests/workloads/kustomization.yaml accordingly."
