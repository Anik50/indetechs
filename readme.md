# Indetechs Kubernetes Technical Assessment

## Production-Grade Kubernetes Cluster on KVM with Persistent Storage

This repository documents and stores the configuration, manifests, scripts, and evidence for a local production-style Kubernetes environment built for the Indetechs Software Limited IT Operations Officer technical assessment.

The environment is deployed on Proxmox VE using KVM/QEMU virtual machines. OPNsense provides routing and firewall functionality, with WireGuard VPN access into the private management subnet. Kubernetes is deployed using kubeadm with three control-plane nodes, two worker nodes, a dedicated NFS storage VM, Canal CNI, kube-vip for the Kubernetes API virtual IP, kube-vip LoadBalancer support, Traefik API gateway, Metrics Server, Headlamp dashboard, NFS CSI dynamic storage provisioning, and a containerized three-tier application.

The final logging direction for application logs is ELK-based centralized logging using Elasticsearch, Logstash, Kibana, and Filebeat.

---

## Current Progress

| Phase    | Scope                                                                                                                          | Status                |
| -------- | ------------------------------------------------------------------------------------------------------------------------------ | --------------------- |
| Phase 1  | KVM infrastructure setup                                                                                                       | Complete              |
| Phase 2  | Kubernetes cluster setup, storage, networking, and security controls                                                           | Complete              |
| Phase 3  | 3-tier application deployment with Traefik, kube-vip LoadBalancer, HPA, NetworkPolicies, and NFS-backed PostgreSQL persistence | Complete              |
| Phase 4+ | Optional automation, ELK logging, DR, CI/CD, testing, and deeper operational runbooks                                          | Pending / Future work |

---

## High-Level Architecture

```text
                         Internet / Upstream
                                |
                              vmbr0
                                |
                            OPNsense
                                |
                  Private Management Network
                         192.168.30.0/24
                                |
                              vmbr1
                                |
     -----------------------------------------------------------------
     |            |            |            |           |             |
kubemaster-1  kubemaster-2  kubemaster-3  worker-1  worker-2        nfs
192.168.30.240 .241         .242          .243      .244            .235
     |            |            |            |           |             |
     -----------------------------------------------------------------
                         Kubernetes API VIP
                          192.168.30.250

                         kube-vip LB Pool
                     192.168.30.200-192.168.30.219

                         Traefik API Gateway
                          192.168.30.200


                  Isolated Storage Network
                      192.168.32.0/24
                              vmbr2
                                |
     -----------------------------------------------------------------
     |            |            |            |           |             |
kubemaster-1  kubemaster-2  kubemaster-3  worker-1  worker-2        nfs
192.168.32.11 .12          .13           .21       .22             .10
                                                                    |
                                                            /srv/nfs/k8s
```

---

## Phase 3 Application Traffic Flow

```text
User / VPN Client
  -> kube-vip LoadBalancer IP: 192.168.30.200
  -> Traefik API Gateway
  -> ops-frontend service
  -> ops-backend service
  -> ops-database PostgreSQL service
  -> NFS-backed PersistentVolumeClaim
```

---

## Logging Traffic Flow

```text
Application Pods
  -> stdout / stderr container logs
  -> Node log files under /var/log/pods
  -> Filebeat DaemonSet
  -> Logstash
  -> Elasticsearch
  -> Kibana
```

Filebeat is intended to run as a DaemonSet so that one Filebeat pod runs on each Kubernetes node and collects container logs from that node. Logstash receives the logs, applies pipeline processing, and forwards structured events into Elasticsearch. Kibana is used to search and visualize application logs.

---

## VM Inventory

| VM             |        Management IP |      Storage IP | Role                              |
| -------------- | -------------------: | --------------: | --------------------------------- |
| `kubemaster-1` |     `192.168.30.240` | `192.168.32.11` | Kubernetes control plane          |
| `kubemaster-2` |     `192.168.30.241` | `192.168.32.12` | Kubernetes control plane          |
| `kubemaster-3` |     `192.168.30.242` | `192.168.32.13` | Kubernetes control plane          |
| `kubeworker-1` |     `192.168.30.243` | `192.168.32.21` | Kubernetes worker                 |
| `kubeworker-2` |     `192.168.30.244` | `192.168.32.22` | Kubernetes worker                 |
| `nfs`          |     `192.168.30.235` | `192.168.32.10` | Dedicated NFS storage server      |
| `opnsense`     | Environment-specific |             N/A | Router, firewall, and VPN gateway |

---

## Cluster Summary

| Component                        | Value                           |
| -------------------------------- | ------------------------------- |
| Kubernetes version               | `v1.36.2`                       |
| OS                               | Ubuntu Server 24.04.4 LTS       |
| Kernel                           | `6.8.0-124-generic`             |
| Container runtime                | `containerd://2.3.2`            |
| CNI                              | Canal                           |
| Pod CIDR                         | `10.244.0.0/16`                 |
| Service CIDR                     | `10.96.0.0/12`                  |
| Kubernetes API VIP               | `192.168.30.250`                |
| Service LoadBalancer provider    | kube-vip                        |
| LoadBalancer IP pool             | `192.168.30.200-192.168.30.219` |
| API Gateway / Ingress Controller | Traefik                         |
| Traefik LoadBalancer IP          | `192.168.30.200`                |
| Storage backend                  | NFS + NFS CSI                   |
| Default StorageClass             | `nfs-csi`                       |
| Dashboard                        | Headlamp                        |
| Metrics                          | Metrics Server                  |
| Application logging              | ELK with Filebeat               |

---

## Platform Components

| Component                     | Namespace                | Deployment Method                     | Purpose                                                     |
| ----------------------------- | ------------------------ | ------------------------------------- | ----------------------------------------------------------- |
| Canal CNI                     | `kube-system`            | Kubernetes manifests                  | Pod networking and NetworkPolicy support                    |
| kube-vip API VIP              | control-plane static pod | Static pod                            | Highly available Kubernetes API virtual IP                  |
| kube-vip service LoadBalancer | `kube-system`            | Kubernetes manifests                  | LoadBalancer IP advertisement for services                  |
| kube-vip cloud provider       | `kube-system`            | Kubernetes manifests                  | Assigns service LoadBalancer IPs from the configured pool   |
| NFS CSI Driver                | `kube-system`            | Helm                                  | Dynamic provisioning of NFS-backed PersistentVolumes        |
| Traefik                       | `traefik`                | Helm                                  | HTTP application gateway and Ingress controller             |
| Headlamp                      | `headlamp`               | Helm                                  | Kubernetes dashboard visibility                             |
| Metrics Server                | `kube-system`            | Kubernetes manifests / cluster add-on | Resource metrics for HPA and operational checks             |
| ELK stack                     | `elastic-stack`          | Helm / ECK                            | Centralized application log storage, processing, and search |
| Filebeat                      | `elastic-stack`          | ECK Beat resource / DaemonSet         | Collects Kubernetes application logs from nodes             |

Helm is used for platform-level services where chart-based lifecycle management is helpful. Application workloads are deployed with Kubernetes manifests and Kustomize so the workload configuration remains transparent and easy to review.

---

## Repository Structure

```text
.
├── README.md
├── 3-tier-app/
│   ├── README.md
│   ├── frontend/
│   │   ├── Dockerfile
│   │   ├── index.html
│   │   ├── nginx.conf
│   │   └── README.md
│   ├── backend/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   ├── server.js
│   │   └── README.md
│   └── database/
│       ├── Dockerfile
│       ├── init.sql
│       └── README.md
├── docs/
│   ├── headlamp-dashboard.md
│   ├── kube-vip-loadbalancer.md
│   ├── network-topology.md
│   ├── phase-1-infrastructure.md
│   ├── phase-2-kubernetes-cluster.md
│   ├── phase-3-application-deployment.md
│   ├── security-hardening.md
│   ├── storage-design.md
│   ├── traefik-api-gateway.md
│   └── elk-logging.md
├── manifests/
│   ├── kube-vip/
│   │   ├── kube-vip-services-ds.yaml
│   │   ├── kubevip-ip-pool.yaml
│   │   └── README.md
│   ├── namespaces/
│   │   └── app-namespaces.yaml
│   ├── pdb/
│   │   └── .gitkeep
│   ├── security/
│   │   └── cluster-security.yaml
│   ├── storage/
│   │   ├── nfs-pvc-test.yaml
│   │   └── nfs-storageclass.yaml
│   ├── traefik/
│   │   ├── README.md
│   │   ├── traefik-values.yaml
│   │   ├── traefik-service.yaml
│   │   └── traefik-ingressclass.yaml
│   ├── observability/
│   │   └── elk/
│   │       ├── eck-stack-values.yaml
│   │       ├── filebeat.yaml
│   │       └── logstash-pipeline.yaml
│   └── workloads/
│       ├── app-config.yaml
│       ├── app-secret.example.yaml
│       ├── backend.yaml
│       ├── database.yaml
│       ├── frontend-hpa.yaml
│       ├── frontend.yaml
│       ├── ingress.yaml
│       ├── kustomization.yaml
│       └── networkpolicy-allow-traefik.yaml
├── screenshots/
│   ├── .gitkeep
│   └── headlamp-workloads.png
└── scripts/
    ├── build-push-phase3-images.sh
    ├── create-phase3-secret.sh
    ├── deploy-elk-logging.sh
    ├── deploy-phase3.sh
    ├── verify-elk-logging.sh
    ├── verify-phase1.sh
    ├── verify-phase2.sh
    └── verify-phase3.sh
```

---

## Phase Documentation

| Document                                 | Purpose                                                                |
| ---------------------------------------- | ---------------------------------------------------------------------- |
| `docs/phase-1-infrastructure.md`         | KVM, Proxmox, VM, OS, SSH, and host preparation details                |
| `docs/phase-2-kubernetes-cluster.md`     | Kubernetes bootstrap, node joining, CNI, storage, and cluster controls |
| `docs/phase-3-application-deployment.md` | Application deployment, service exposure, persistence, and validation  |
| `docs/network-topology.md`               | Management, storage, VIP, and service exposure network design          |
| `docs/storage-design.md`                 | NFS server, NFS CSI, StorageClass, PVC, and persistence decisions      |
| `docs/security-hardening.md`             | Infrastructure and Kubernetes hardening controls                       |
| `docs/headlamp-dashboard.md`             | Dashboard deployment and operational visibility                        |
| `docs/kube-vip-loadbalancer.md`          | API VIP and service LoadBalancer design                                |
| `docs/traefik-api-gateway.md`            | Traefik gateway and Ingress routing                                    |
| `docs/elk-logging.md`                    | ELK and Filebeat centralized application logging design                |

---

## Main Manifests

| Manifest                                               | Purpose                                                                         |
| ------------------------------------------------------ | ------------------------------------------------------------------------------- |
| `manifests/storage/nfs-storageclass.yaml`              | NFS CSI StorageClass                                                            |
| `manifests/storage/nfs-pvc-test.yaml`                  | NFS dynamic provisioning test                                                   |
| `manifests/namespaces/app-namespaces.yaml`             | Application environment namespaces                                              |
| `manifests/security/cluster-security.yaml`             | LimitRange, ResourceQuota, NetworkPolicies, and PDBs                            |
| `manifests/kube-vip/kube-vip-services-ds.yaml`         | kube-vip service LoadBalancer advertisement DaemonSet                           |
| `manifests/kube-vip/kubevip-ip-pool.yaml`              | kube-vip LoadBalancer IP pool ConfigMap                                         |
| `manifests/traefik/traefik-values.yaml`                | Helm values used for Traefik deployment                                         |
| `manifests/traefik/traefik-service.yaml`               | Captured Traefik LoadBalancer service                                           |
| `manifests/traefik/traefik-ingressclass.yaml`          | Captured Traefik IngressClass                                                   |
| `manifests/observability/elk/eck-stack-values.yaml`    | Helm values for Elasticsearch, Kibana, and Logstash                             |
| `manifests/observability/elk/filebeat.yaml`            | Filebeat DaemonSet / ECK Beat configuration for Kubernetes logs                 |
| `manifests/observability/elk/logstash-pipeline.yaml`   | Logstash pipeline for receiving Filebeat events and forwarding to Elasticsearch |
| `manifests/workloads/kustomization.yaml`               | Kustomize entrypoint for Phase 3 workload deployment                            |
| `manifests/workloads/app-config.yaml`                  | Application ConfigMap                                                           |
| `manifests/workloads/app-secret.example.yaml`          | Example Secret manifest                                                         |
| `manifests/workloads/database.yaml`                    | PostgreSQL StatefulSet, Service, and PVC                                        |
| `manifests/workloads/backend.yaml`                     | Backend API Deployment and Service                                              |
| `manifests/workloads/frontend.yaml`                    | Frontend Deployment and Service                                                 |
| `manifests/workloads/frontend-hpa.yaml`                | HorizontalPodAutoscaler for frontend                                            |
| `manifests/workloads/networkpolicy-allow-traefik.yaml` | NetworkPolicy allowing Traefik to reach frontend                                |
| `manifests/workloads/ingress.yaml`                     | Traefik Ingress route for the application                                       |

---

## Phase 1 Summary

Phase 1 establishes the virtualized infrastructure foundation.

Key items completed:

* Proxmox VE host used as the KVM/QEMU virtualization platform
* OPNsense VM deployed for routing, firewalling, and VPN access
* Separate management and storage networks created
* Ubuntu Server VMs provisioned for control-plane, worker, and NFS roles
* Static IP addressing configured
* SSH access hardened with key-based authentication
* Kubernetes host prerequisites configured
* containerd installed and configured
* swap disabled
* required kernel modules and sysctl settings applied

Verification script:

```bash
bash scripts/verify-phase1.sh
```

---

## Phase 2 Summary

Phase 2 builds the Kubernetes platform on top of the VM infrastructure.

Key items completed:

* Kubernetes cluster initialized using kubeadm
* Three control-plane nodes joined
* Two worker nodes joined
* kube-vip configured for highly available Kubernetes API access
* Canal CNI installed
* Metrics Server installed
* Headlamp dashboard installed
* NFS CSI driver installed
* Default NFS-backed StorageClass configured
* Dynamic PVC provisioning tested
* Application namespaces created
* ResourceQuota and LimitRange configured
* NetworkPolicies prepared
* Pod Disruption Budgets prepared

Verification script:

```bash
bash scripts/verify-phase2.sh
```

---

## Phase 3 Summary

Phase 3 deploys a lightweight production-style three-tier application on top of the Kubernetes platform.

The application is the Indetechs 3-Tier Operations Task Portal. It provides a simple web interface where tasks can be created, listed, marked complete, and deleted. The application is intentionally lightweight to fit local KVM resource constraints while still demonstrating a complete frontend, backend, and database architecture.

| Tier     | Technology          | Kubernetes Object           |
| -------- | ------------------- | --------------------------- |
| Frontend | Nginx static web UI | Deployment + Service        |
| Backend  | Node.js Express API | Deployment + Service        |
| Database | PostgreSQL          | StatefulSet + Service + PVC |

Phase 3 also includes:

* kube-vip LoadBalancer support for Kubernetes Service objects
* Traefik API gateway exposed through kube-vip
* NFS-backed persistent PostgreSQL storage
* ConfigMap-based application configuration
* Secret-based database credentials
* Health checks for application pods
* Resource requests and limits
* Frontend HorizontalPodAutoscaler
* NetworkPolicy-controlled communication between tiers
* Traefik Ingress routing to the frontend service

---

## Phase 3 Application Details

| Item                    | Value                                        |
| ----------------------- | -------------------------------------------- |
| Namespace               | `app-prod`                                   |
| Frontend Deployment     | `ops-frontend`                               |
| Backend Deployment      | `ops-backend`                                |
| Database StatefulSet    | `ops-database`                               |
| Frontend Service        | `ops-frontend`                               |
| Backend Service         | `ops-backend`                                |
| Database Service        | `ops-database`                               |
| Database PVC            | `postgres-data-ops-database-0`               |
| StorageClass            | `nfs-csi`                                    |
| Ingress                 | `ops-ingress`                                |
| Ingress host            | `ops.indetechs.local`                        |
| Traefik LoadBalancer IP | `192.168.30.200`                             |
| Frontend HPA            | `ops-frontend`, min 2, max 4, CPU target 70% |

---

## kube-vip LoadBalancer Support

kube-vip is used for two separate purposes in this cluster.

| Purpose                   | IP / Range                      | Implementation                                        |
| ------------------------- | ------------------------------- | ----------------------------------------------------- |
| Kubernetes API HA         | `192.168.30.250`                | Existing kube-vip static pods                         |
| Service LoadBalancer VIPs | `192.168.30.200-192.168.30.219` | kube-vip services DaemonSet + kube-vip cloud provider |

The existing API VIP static pod configuration was left unchanged.

A separate kube-vip services DaemonSet was deployed for service LoadBalancer advertisement with:

```text
cp_enable=false
svc_enable=true
vip_arp=true
vip_interface=ens18
vip_subnet=/32
svc_election=true
```

The kube-vip cloud provider assigns LoadBalancer IPs from the `kubevip` ConfigMap:

```yaml
data:
  range-global: 192.168.30.200-192.168.30.219
```

Validation was performed with a temporary nginx LoadBalancer service. The service received `192.168.30.200`, and HTTP access returned `200 OK`.

---

## Traefik API Gateway

Traefik is deployed inside Kubernetes as the application ingress/API gateway.

| Item         | Value            |
| ------------ | ---------------- |
| Namespace    | `traefik`        |
| Service type | `LoadBalancer`   |
| External IP  | `192.168.30.200` |
| IngressClass | `traefik`        |
| HTTP port    | `80`             |
| HTTPS port   | `443`            |

Before application Ingress routes were created, direct access to the Traefik LoadBalancer IP returned:

```text
HTTP/1.1 404 Not Found
```

This was expected and confirmed that traffic reached Traefik successfully.

After the application Ingress was applied, the application became available through:

```text
http://ops.indetechs.local
```

For local browser access, the client machine must resolve the hostname to the Traefik LoadBalancer IP:

```text
192.168.30.200 ops.indetechs.local
```

---

## ELK Application Logging

The project uses an ELK-based design for centralized application logging.

| Component     | Purpose                                                                                   |
| ------------- | ----------------------------------------------------------------------------------------- |
| Elasticsearch | Stores and indexes application log events                                                 |
| Logstash      | Receives Filebeat events, applies pipeline processing, and forwards logs to Elasticsearch |
| Kibana        | Provides log search and visualization                                                     |
| Filebeat      | Runs on Kubernetes nodes and collects container logs from application pods                |

The initial logging target is the application namespace:

```text
app-prod
```

The expected log path on Kubernetes nodes is:

```text
/var/log/pods/*/*/*.log
```

Filebeat enriches logs with Kubernetes metadata such as namespace, pod name, labels, and node name. This makes it possible to filter application logs in Kibana by fields such as:

```text
kubernetes.namespace
kubernetes.pod.name
kubernetes.container.name
kubernetes.labels.app
```

Recommended Kibana queries:

```text
kubernetes.namespace : "app-prod"
```

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

## ELK Deployment

ELK is planned to be deployed using the Elastic Helm repository and ECK-managed Elastic Stack resources.

Add the Elastic Helm repository:

```bash
helm repo add elastic https://helm.elastic.co
helm repo update
```

Install the ECK Operator:

```bash
helm install elastic-operator elastic/eck-operator \
  -n elastic-system \
  --create-namespace
```

Deploy the Elastic Stack values:

```bash
helm install elastic-stack elastic/eck-stack \
  -n elastic-stack \
  --create-namespace \
  -f manifests/observability/elk/eck-stack-values.yaml
```

Deploy Filebeat log collection:

```bash
kubectl apply -f manifests/observability/elk/filebeat.yaml
```

Verify the ELK stack:

```bash
kubectl get pods -n elastic-system
kubectl get pods -n elastic-stack
kubectl get elasticsearch,kibana,beat,logstash -n elastic-stack
```

Get the Kibana service:

```bash
kubectl get svc -n elastic-stack
```

Port-forward Kibana for local access:

```bash
kubectl port-forward -n elastic-stack svc/elastic-stack-eck-kibana-kb-http 5601:5601
```

Open Kibana locally:

```text
https://localhost:5601
```

Get the default Elasticsearch user password:

```bash
kubectl get secret -n elastic-stack elastic-stack-eck-elasticsearch-es-elastic-user \
  -o go-template='{{.data.elastic | base64decode}}'
```

---

## Phase 3 Deployment

Build and push the application container images:

```bash
IMAGE_REGISTRY=docker.io/anik50 TAG=v3 bash scripts/build-push-phase3-images.sh
```

Create the application Secret:

```bash
bash scripts/create-phase3-secret.sh
```

Deploy the Phase 3 workloads:

```bash
kubectl apply -k manifests/workloads
```

Alternatively, use the deployment helper script:

```bash
bash scripts/deploy-phase3.sh
```

Verify Phase 3:

```bash
bash scripts/verify-phase3.sh
```

---

## Phase 3 Verification Evidence

The deployed application was verified with:

```bash
kubectl -n app-prod get pods,svc,pvc,ingress,hpa -o wide
```

Observed result:

```text
pod/ops-backend-64dfbdb579-969rx    1/1   Running
pod/ops-backend-64dfbdb579-tdcvp    1/1   Running
pod/ops-database-0                  1/1   Running
pod/ops-frontend-5767dfd9c8-nl7q2   1/1   Running
pod/ops-frontend-5767dfd9c8-vx4nj   1/1   Running

service/ops-backend    ClusterIP   10.103.181.178   <none>   8080/TCP
service/ops-database   ClusterIP   10.103.71.128    <none>   5432/TCP
service/ops-frontend   ClusterIP   10.97.215.133    <none>   8080/TCP

persistentvolumeclaim/postgres-data-ops-database-0   Bound   2Gi   RWO   nfs-csi

ingress.networking.k8s.io/ops-ingress   traefik   ops.indetechs.local   192.168.30.200   80

horizontalpodautoscaler.autoscaling/ops-frontend   Deployment/ops-frontend   cpu: 4%/70%   2   4   2
```

The verification script also confirmed that the frontend and backend API were reachable through Traefik:

```text
Frontend reachable through Traefik
Backend API reachable through Traefik
Phase 3 verification completed successfully.
```

---

## Persistent Storage Verification

Application-level persistence was verified by writing a task through the public Traefik route, deleting the PostgreSQL pod, waiting for the StatefulSet to recreate the pod, and reading the data back through the same API.

Command sequence:

```bash
curl -H "Host: ops.indetechs.local" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"title":"Persistence test before database restart"}' \
  http://192.168.30.200/api/tasks

kubectl -n app-prod delete pod ops-database-0

kubectl -n app-prod rollout status statefulset/ops-database

curl -H "Host: ops.indetechs.local" \
  http://192.168.30.200/api/tasks
```

Result:

```text
{"id":6,"title":"Persistence test before database restart","completed":false,"created_at":"2026-06-23T14:29:42.188Z"}

pod "ops-database-0" deleted from app-prod namespace

Waiting for 1 pods to be ready...
partitioned roll out complete: 1 new pods have been updated...

[
  {"id":6,"title":"Persistence test before database restart","completed":false,"created_at":"2026-06-23T14:29:42.188Z"},
  {"id":5,"title":"Phase 3 verification item","completed":false,"created_at":"2026-06-23T14:16:37.340Z"},
  {"id":4,"title":"Phase 3 verification item","completed":false,"created_at":"2026-06-23T14:13:28.501Z"},
  {"id":3,"title":"Phase 3 verification item","completed":false,"created_at":"2026-06-23T14:09:37.844Z"},
  {"id":2,"title":"Phase 3 deployment validated","completed":false,"created_at":"2026-06-23T14:05:02.730Z"},
  {"id":1,"title":"Verify persistent PostgreSQL storage on NFS","completed":false,"created_at":"2026-06-23T14:02:14.205Z"}
]
```

The task `Persistence test before database restart` remained present after `ops-database-0` was deleted and recreated. This verifies that PostgreSQL data persisted through the NFS-backed PVC `postgres-data-ops-database-0`.

---

## Quick Verification

General cluster verification:

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get storageclass,pv,pvc -A
kubectl get limitrange,resourcequota,networkpolicy,pdb -n app-prod
kubectl top nodes
```

kube-vip and Traefik verification:

```bash
kubectl -n kube-system get pods -o wide | grep kube-vip
kubectl -n kube-system get configmap kubevip -o yaml
kubectl -n traefik get pods -o wide
kubectl -n traefik get svc -o wide
kubectl get ingressclass
kubectl get svc -A | grep LoadBalancer
curl -I http://192.168.30.200
```

Phase 3 workload verification:

```bash
kubectl get pods,svc,pvc,ingress,hpa -n app-prod
kubectl describe ingress -n app-prod
kubectl get networkpolicy -n app-prod
bash scripts/verify-phase3.sh
```

Application verification through Traefik:

```bash
curl -H "Host: ops.indetechs.local" http://192.168.30.200/
curl -H "Host: ops.indetechs.local" http://192.168.30.200/api/tasks
```

ELK logging verification:

```bash
kubectl get pods -n elastic-stack
kubectl get beat -n elastic-stack
kubectl logs -n elastic-stack daemonset/filebeat-filebeat
kubectl port-forward -n elastic-stack svc/elastic-stack-eck-kibana-kb-http 5601:5601
```

Kibana query for application logs:

```text
kubernetes.namespace : "app-prod"
```

---

## Security Notes

The cluster uses a private management network and VPN-based access model. Kubernetes services are not intentionally exposed directly to the public internet.

Security controls include:

* OPNsense firewall boundary
* WireGuard VPN access
* SSH hardening
* key-based SSH authentication
* non-root administrative user
* Kubernetes namespaces for environment separation
* ResourceQuota and LimitRange in `app-prod`
* default-deny NetworkPolicy baseline
* explicit tier-to-tier NetworkPolicy rules
* Traefik ingress/API gateway instead of direct pod access
* NFS storage traffic isolated on a dedicated storage subnet
* application logs centralized through Filebeat instead of direct node access

---

## Storage Notes

Persistent application storage is provided by the NFS CSI driver using the default `nfs-csi` StorageClass.

The PostgreSQL database tier uses a PersistentVolumeClaim backed by the NFS server:

| Item           | Value                          |
| -------------- | ------------------------------ |
| NFS server     | `192.168.32.10`                |
| Export         | `/srv/nfs/k8s`                 |
| StorageClass   | `nfs-csi`                      |
| PVC            | `postgres-data-ops-database-0` |
| Reclaim policy | `Retain`                       |

The NFS StorageClass uses dynamic provisioning and a Retain reclaim policy.

---

## Design Decisions and Trade-offs

### Ubuntu Server 24.04 LTS

Ubuntu Server 24.04 LTS was selected because it provides a stable, long-term-supported Linux base with good Kubernetes, containerd, and cloud-native ecosystem compatibility. It is widely used in production and has predictable package and security maintenance.

### Proxmox VE with KVM/QEMU

Proxmox VE was used as the KVM/QEMU virtualization platform because it provides a practical way to manage local virtual machines, virtual networks, bridges, storage, snapshots, and console access while still using KVM underneath.

### OPNsense and WireGuard

OPNsense provides a clear firewall and routing boundary for the lab. WireGuard allows private access into the management subnet without exposing Kubernetes services directly to the public internet.

### Canal CNI

Canal was selected because it combines Flannel-style pod networking with Calico NetworkPolicy support. This is a practical fit for a small local Kubernetes cluster where simple routing and working NetworkPolicy enforcement are both required.

### NFS CSI Storage

NFS CSI was selected for persistent storage because the assessment environment is local and VM-based. A dedicated NFS VM keeps storage traffic separate from management traffic using the isolated storage subnet. This provides simple dynamic provisioning and enough persistence for the three-tier application.

The main limitation is that a single NFS server is not fully redundant. For a larger production deployment, Longhorn or Rook/Ceph would be considered for replicated distributed storage.

### kube-vip LoadBalancer

kube-vip was already used for Kubernetes API high availability, so it was extended to support LoadBalancer services. This avoids introducing a second load-balancer technology and keeps the design consistent.

### Traefik API Gateway

Traefik was selected as the API gateway because it integrates cleanly with Kubernetes Ingress resources and can be exposed using a private kube-vip LoadBalancer IP. OPNsense remains the network edge firewall and VPN boundary, while Traefik handles HTTP routing inside the Kubernetes platform.

### ELK Logging

ELK was selected for centralized application logging because it provides log ingestion, indexing, search, and visualization in one stack. Filebeat is suitable for Kubernetes node-level log collection because it can run as a DaemonSet and enrich container logs with Kubernetes metadata.

---

## Operational Notes

kube-vip was initially deployed only for Kubernetes API high availability through the API VIP `192.168.30.250`.

During Phase 3 preparation, kube-vip was extended to support Kubernetes Service objects of type `LoadBalancer`. This was implemented using a separate service-only kube-vip DaemonSet and the kube-vip cloud provider. The LoadBalancer IP pool is `192.168.30.200-192.168.30.219`.

Traefik is deployed as the cluster API gateway using a kube-vip LoadBalancer IP. The Phase 3 application is exposed through Traefik rather than directly through NodePort services.

The Phase 2 NetworkPolicies and Pod Disruption Budgets were created in advance for the three-tier application. Their runtime behavior is validated in Phase 3 after deploying frontend, backend, and database pods using the expected labels.

ELK logging is treated as an optional extension phase. Filebeat should collect application container logs from the Kubernetes nodes and forward them to Logstash for processing before indexing in Elasticsearch.

---

## Future Improvements

The mandatory core phases have been completed. The following items are planned as future improvements under the optional extension phases:

* Add Terraform or Ansible automation for VM provisioning and full cluster rebuilds
* Complete ELK deployment for centralized application logging
* Add Filebeat filtering so only `app-prod` logs are forwarded initially
* Add scheduled PostgreSQL backup automation
* Define and test RTO/RPO targets
* Add load testing and performance analysis
* Add Pod Security Admission profiles
* Add CI/CD for automated image builds and Kubernetes deployment
* Add automated rollback for failed deployments
* Add more detailed operational runbooks for node replacement, scaling, backup, and recovery

```
```
