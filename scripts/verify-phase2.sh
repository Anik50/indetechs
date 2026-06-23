#!/usr/bin/env bash
set -euo pipefail

echo "== Nodes =="
kubectl get nodes -o wide

echo
echo "== System pods =="
kubectl get pods -A

echo
echo "== Cluster health =="
kubectl get --raw='/readyz?verbose' || true

echo
echo "== Storage =="
kubectl get storageclass,pv,pvc -A

echo
echo "== Phase 2.4 security resources =="
kubectl get limitrange,resourcequota,networkpolicy,pdb -n app-prod

echo
echo "== Metrics =="
kubectl top nodes || true
