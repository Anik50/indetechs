#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-app-prod}"
APP_HOST="${APP_HOST:-ops.indetechs.local}"
LB_IP="${LB_IP:-192.168.30.200}"

echo "== Phase 3 workload overview =="
kubectl -n "${NAMESPACE}" get deploy,sts,svc,ingress,hpa,pvc -o wide

echo
echo "== Pods =="
kubectl -n "${NAMESPACE}" get pods -o wide

echo
echo "== Rollout status =="
kubectl -n "${NAMESPACE}" rollout status statefulset/ops-database --timeout=120s
kubectl -n "${NAMESPACE}" rollout status deployment/ops-backend --timeout=120s
kubectl -n "${NAMESPACE}" rollout status deployment/ops-frontend --timeout=120s

echo
echo "== Storage =="
kubectl -n "${NAMESPACE}" get pvc
kubectl get pv | grep task || true

echo
echo "== HPA =="
kubectl -n "${NAMESPACE}" get hpa ops-frontend

echo
echo "== NetworkPolicies =="
kubectl -n "${NAMESPACE}" get networkpolicy

echo
echo "== Traefik =="
kubectl -n traefik get svc traefik -o wide
kubectl get ingressclass traefik

echo
echo "== App HTTP checks through Traefik =="
curl -fsS -H "Host: ${APP_HOST}" "http://${LB_IP}/" >/dev/null
echo "Frontend reachable through Traefik"

curl -fsS -H "Host: ${APP_HOST}" "http://${LB_IP}/api/tasks" >/dev/null
echo "Backend API reachable through Traefik"

echo
echo "== Sample persistence write =="
curl -fsS -H "Host: ${APP_HOST}" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Phase 3 verification item"}' \
  "http://${LB_IP}/api/tasks" >/dev/null
curl -fsS -H "Host: ${APP_HOST}" "http://${LB_IP}/api/tasks"

echo
echo "Phase 3 verification completed successfully."
