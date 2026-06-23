#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-app-prod}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-ChangeMe_Phase3_Lab_Only_2026}"

kubectl get namespace "${NAMESPACE}" >/dev/null

kubectl -n "${NAMESPACE}" create secret generic todo-db-secret \
  --from-literal=POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret todo-db-secret is present in namespace ${NAMESPACE}."
