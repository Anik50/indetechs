#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f manifests/namespaces/app-namespaces.yaml
kubectl apply -f manifests/security/cluster-security.yaml
bash scripts/create-phase3-secret.sh
kubectl apply -k manifests/workloads

kubectl -n app-prod rollout status statefulset/todo-database --timeout=180s
kubectl -n app-prod rollout status deployment/todo-backend --timeout=180s
kubectl -n app-prod rollout status deployment/todo-frontend --timeout=180s

bash scripts/verify-phase3.sh
