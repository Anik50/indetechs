# Optional Observability: ECK-managed Elasticsearch, Kibana, and Filebeat

## Status

This observability layer is included as an optional extension.

The stack was prepared using **Elastic Cloud on Kubernetes (ECK)**. Elasticsearch and Kibana are deployed using the ECK Stack Helm chart, and Filebeat is deployed as an ECK `Beat` resource.

Elasticsearch was successfully deployed and reached a running state. Kibana was scheduled and connected to Elasticsearch, but it did not remain healthy in the final lab environment because of limited available memory on the KVM host.

During testing, Kibana restarted with the following memory error:

```text
FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed - JavaScript heap out of memory
```

For that reason, this section is documented as prepared and partially validated optional work rather than a fully verified completed component.

---

## Logging Flow

```text
Application Pods
  -> stdout / stderr
  -> Kubernetes node log files
  -> Filebeat
  -> Elasticsearch
  -> Kibana
```

Filebeat collects Kubernetes container logs from the nodes and sends them directly to Elasticsearch. Kibana is used to search and visualize the logs.

The initial logging scope is focused on the application namespace:

```text
app-prod
```

---

## Files

```text
manifests/observability/elk/
├── README.md
├── eck-stack-values.yaml
└── filebeat.yaml
```

| File                    | Purpose                                                              |
| ----------------------- | -------------------------------------------------------------------- |
| `eck-stack-values.yaml` | Helm values for Elasticsearch and Kibana through the ECK Stack chart |
| `filebeat.yaml`         | Filebeat ECK Beat resource and required RBAC                         |

---

## Deployment Steps

Run these commands from the repository root.

### 1. Add the Elastic Helm repository

```bash
helm repo add elastic https://helm.elastic.co
helm repo update
```

### 2. Install the ECK Operator

```bash
helm install elastic-operator elastic/eck-operator \
  -n elastic-system \
  --create-namespace
```

Verify:

```bash
kubectl get pods -n elastic-system
```

### 3. Deploy Elasticsearch and Kibana

```bash
helm install elastic-stack elastic/eck-stack \
  -n elastic-stack \
  --create-namespace \
  -f manifests/observability/elk/eck-stack-values.yaml
```

For updates:

```bash
helm upgrade elastic-stack elastic/eck-stack \
  -n elastic-stack \
  -f manifests/observability/elk/eck-stack-values.yaml
```

Verify:

```bash
kubectl get elasticsearch,kibana -n elastic-stack
kubectl get pods -n elastic-stack -o wide
kubectl get pvc -n elastic-stack
```

Expected result when enough resources are available:

```text
elasticsearch-es-default-0   Running
kibana-kb-...                Running
```

### 4. Deploy Filebeat

```bash
kubectl apply -f manifests/observability/elk/filebeat.yaml
```

Verify:

```bash
kubectl get beat -n elastic-stack
kubectl get daemonset -n elastic-stack
kubectl get pods -n elastic-stack -o wide | grep filebeat
```

---

## Accessing Kibana

Kibana is kept private inside the cluster.

Check the service name:

```bash
kubectl get svc -n elastic-stack
```

Port-forward the Kibana service:

```bash
kubectl port-forward -n elastic-stack svc/kibana-kb-http 5601:5601
```

Open:

```text
https://localhost:5601
```

---

## Kibana Login

The default username is:

```text
elastic
```

Find the generated Elasticsearch user secret:

```bash
kubectl get secret -n elastic-stack | grep elastic
```

Retrieve the password:

```bash
kubectl get secret -n elastic-stack elasticsearch-es-elastic-user \
  -o go-template='{{.data.elastic | base64decode}}'
```

Use that password to log in to Kibana.

---

## Verification Plan

Generate traffic against the application:

```bash
curl -H "Host: ops.indetechs.local" http://192.168.30.200/
curl -H "Host: ops.indetechs.local" http://192.168.30.200/api/tasks
```

Check Elastic resources:

```bash
kubectl get pods -n elastic-system
kubectl get pods -n elastic-stack -o wide
kubectl get elasticsearch,kibana,beat -n elastic-stack
```

Check Filebeat:

```bash
kubectl get beat -n elastic-stack
kubectl get daemonset -n elastic-stack
kubectl logs -n elastic-stack daemonset/filebeat-beat-filebeat
```

If the DaemonSet name is different, find it with:

```bash
kubectl get daemonset -n elastic-stack
```

In Kibana, search for logs from the application namespace:

```text
kubernetes.namespace : "app-prod"
```

Useful filters:

```text
kubernetes.namespace : "app-prod" and kubernetes.pod.name : ops-backend*
```

```text
kubernetes.namespace : "app-prod" and kubernetes.pod.name : ops-frontend*
```

```text
kubernetes.namespace : "app-prod" and kubernetes.pod.name : ops-database*
```

---

## Troubleshooting

### Kibana Restarts or Is Not Ready

Check the pod and events:

```bash
kubectl get pods -n elastic-stack -o wide
kubectl describe pod -n elastic-stack -l kibana.k8s.elastic.co/name=kibana
kubectl get events -n elastic-stack --sort-by=.lastTimestamp
```

Check Kibana logs:

```bash
kubectl logs -n elastic-stack <kibana-pod-name> --tail=200
kubectl logs -n elastic-stack <kibana-pod-name> --previous --tail=200
```

If logs show:

```text
FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed - JavaScript heap out of memory
```

then Kibana needs more memory.

Possible fixes:

* increase Kibana memory request and limit;
* set a larger Node.js heap size for Kibana;
* add a dedicated observability worker node;
* reduce other non-essential workloads;
* move Kibana to a node with more available memory.

---

### Elasticsearch is Pending

Check the pod and PVC:

```bash
kubectl get pods -n elastic-stack -o wide
kubectl describe pod -n elastic-stack -l elasticsearch.k8s.elastic.co/cluster-name=elasticsearch
kubectl get pvc -n elastic-stack
kubectl describe pvc -n elastic-stack
```

Common causes:

* not enough memory;
* PVC not bound;
* NFS CSI storage issue;
* node selector points to the wrong node;
* selected node has no available capacity.

---

### Filebeat is Not Running

Check the Beat resource and DaemonSet:

```bash
kubectl get beat -n elastic-stack
kubectl describe beat filebeat -n elastic-stack
kubectl get daemonset -n elastic-stack
kubectl get pods -n elastic-stack -o wide | grep filebeat
```

Check Filebeat logs:

```bash
kubectl logs -n elastic-stack daemonset/filebeat-beat-filebeat
```

If the DaemonSet name is different, find it with:

```bash
kubectl get daemonset -n elastic-stack
```

---

### No Logs in Kibana

Generate fresh application traffic:

```bash
curl -H "Host: ops.indetechs.local" http://192.168.30.200/api/tasks
```

Confirm that application pods are running in the expected namespace:

```bash
kubectl get pods -n app-prod
```

Check Filebeat logs:

```bash
kubectl logs -n elastic-stack daemonset/filebeat-beat-filebeat
```

Search in Kibana with:

```text
kubernetes.namespace : "app-prod"
```

---

## Cleanup

Remove Filebeat:

```bash
kubectl delete -f manifests/observability/elk/filebeat.yaml
```

Remove Elasticsearch and Kibana:

```bash
helm uninstall elastic-stack -n elastic-stack
```

Remove the ECK Operator:

```bash
helm uninstall elastic-operator -n elastic-system
```

Optional namespace cleanup:

```bash
kubectl delete namespace elastic-stack
kubectl delete namespace elastic-system
```

Check retained storage before deleting any persistent data:

```bash
kubectl get pvc -n elastic-stack
kubectl get pv
```

---

## Future Improvements

With more hardware resources, the next steps would be:

* increase Kibana memory and complete Kibana validation;
* complete Filebeat-to-Elasticsearch validation;
* create Kibana dashboards for frontend, backend, and database logs;
* add a dedicated worker node for observability workloads;
* add infrastructure monitoring with LibreNMS;
* configure alerts for pod restarts, high CPU/memory usage, disk pressure, and storage issues;
* add log retention policies;
* document backup and restore for Elasticsearch data.
