# Indetechs Kubernetes Technical Assessment

## Project

This repository documents and stores manifests for a local production-style Kubernetes environment built on KVM virtual machines for the Indetechs Software Limited IT Operations Officer technical assessment.

The environment is deployed on Proxmox VE using KVM/QEMU virtual machines. OPNsense provides routing and firewall functionality, with WireGuard VPN access into the private management subnet. Kubernetes is deployed using `kubeadm` with three control-plane nodes, two worker nodes, a dedicated NFS storage VM, Canal CNI, kube-vip for the Kubernetes API virtual IP, kube-vip LoadBalancer support, Traefik API gateway, Metrics Server, Headlamp, and NFS CSI dynamic storage provisioning.

## Current Progress

| Phase    | Scope                                                                                                                          | Status                |
| -------- | ------------------------------------------------------------------------------------------------------------------------------ | --------------------- |
| Phase 1  | KVM infrastructure setup                                                                                                       | Complete              |
| Phase 2  | Kubernetes cluster setup, storage, networking/security controls                                                                | Complete              |
| Phase 3  | 3-tier application deployment with Traefik, kube-vip LoadBalancer, HPA, NetworkPolicies, and NFS-backed PostgreSQL persistence | Complete              |
| Phase 4+ | Optional automation, observability, DR, CI/CD, testing                                                                         | Pending / Future work |

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

## VM Inventory

| VM             |        Management IP |      Storage IP | Role                         |
| -------------- | -------------------: | --------------: | ---------------------------- |
| `kubemaster-1` |     `192.168.30.240` | `192.168.32.11` | Kubernetes control plane     |
| `kubemaster-2` |     `192.168.30.241` | `192.168.32.12` | Kubernetes control plane     |
| `kubemaster-3` |     `192.168.30.242` | `192.168.32.13` | Kubernetes control plane     |
| `kubeworker-1` |     `192.168.30.243` | `192.168.32.21` | Kubernetes worker            |
| `kubeworker-2` |     `192.168.30.244` | `192.168.32.22` | Kubernetes worker            |
| `nfs`          |     `192.168.30.235` | `192.168.32.10` | Dedicated NFS storage server |
| `opnsense`     | Environment-specific |             N/A | Router/firewall              |

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
│   └── traefik-api-gateway.md
├── manifests/
│   ├── kube-vip/
│   │   ├── kube-vip-services-ds.yaml
│   │   └── kubevip-ip-pool.yaml
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
│   │   ├── traefik-values.yaml
│   │   ├── traefik-service.yaml
│   │   └── traefik-ingressclass.yaml
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
    ├── deploy-phase3.sh
    ├── verify-phase1.sh
    ├── verify-phase2.sh
    └── verify-phase3.sh
```

## Phase Documentation

* [Phase 1 — KVM Infrastructure Setup](docs/phase-1-infrastructure.md)
* [Phase 2 — Kubernetes Cluster Setup](docs/phase-2-kubernetes-cluster.md)
* [Phase 3 — Application Deployment](docs/phase-3-application-deployment.md)
* [Network Topology](docs/network-topology.md)
* [Storage Design](docs/storage-design.md)
* [Security Hardening](docs/security-hardening.md)
* [Headlamp Dashboard](docs/headlamp-dashboard.md)
* [kube-vip LoadBalancer](docs/kube-vip-loadbalancer.md)
* [Traefik API Gateway](docs/traefik-api-gateway.md)

## Main Manifests

| Manifest                                               | Purpose                                               |
| ------------------------------------------------------ | ----------------------------------------------------- |
| `manifests/storage/nfs-storageclass.yaml`              | NFS CSI StorageClass                                  |
| `manifests/storage/nfs-pvc-test.yaml`                  | NFS dynamic provisioning test                         |
| `manifests/namespaces/app-namespaces.yaml`             | App environment namespaces                            |
| `manifests/security/cluster-security.yaml`             | LimitRange, ResourceQuota, NetworkPolicies, and PDBs  |
| `manifests/kube-vip/kube-vip-services-ds.yaml`         | kube-vip service LoadBalancer advertisement DaemonSet |
| `manifests/kube-vip/kubevip-ip-pool.yaml`              | kube-vip LoadBalancer IP pool ConfigMap               |
| `manifests/traefik/traefik-values.yaml`                | Helm values used for Traefik deployment               |
| `manifests/traefik/traefik-service.yaml`               | Captured Traefik LoadBalancer service                 |
| `manifests/traefik/traefik-ingressclass.yaml`          | Captured Traefik IngressClass                         |
| `manifests/workloads/kustomization.yaml`               | Kustomize entrypoint for Phase 3 workload deployment  |
| `manifests/workloads/app-config.yaml`                  | Application ConfigMap                                 |
| `manifests/workloads/app-secret.example.yaml`          | Example Secret manifest                               |
| `manifests/workloads/database.yaml`                    | PostgreSQL StatefulSet, Service, and PVC              |
| `manifests/workloads/backend.yaml`                     | Backend API Deployment and Service                    |
| `manifests/workloads/frontend.yaml`                    | Frontend Deployment and Service                       |
| `manifests/workloads/frontend-hpa.yaml`                | HorizontalPodAutoscaler for frontend                  |
| `manifests/workloads/networkpolicy-allow-traefik.yaml` | NetworkPolicy allowing Traefik to reach frontend      |
| `manifests/workloads/ingress.yaml`                     | Traefik Ingress route for the application             |

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

## Phase 2 Summary

Phase 2 builds the Kubernetes platform on top of the VM infrastructure.

Key items completed:

* Kubernetes cluster initialized using `kubeadm`
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

## Phase 3 Summary

Phase 3 deploys a lightweight production-style three-tier application on top of the Kubernetes platform.

The application is the **Indetechs 3-Tier Operations Task Portal**. It provides a simple web interface where tasks can be created, listed, marked complete, and deleted. The application is intentionally lightweight to fit the local KVM resource constraints while still demonstrating a complete frontend, backend, and database architecture.

The application consists of:

| Tier     | Technology          | Kubernetes Object           |
| -------- | ------------------- | --------------------------- |
| Frontend | Nginx static web UI | Deployment + Service        |
| Backend  | Node.js Express API | Deployment + Service        |
| Database | PostgreSQL          | StatefulSet + Service + PVC |

Phase 3 also includes:

* kube-vip LoadBalancer support for Kubernetes `Service` objects
* Traefik API gateway exposed through kube-vip
* NFS-backed persistent PostgreSQL storage
* ConfigMap-based application configuration
* Secret-based database credentials
* Health checks for application pods
* Resource requests and limits
* Frontend HorizontalPodAutoscaler
* NetworkPolicy-controlled communication between tiers
* Traefik Ingress routing to the frontend service

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

## kube-vip LoadBalancer Support

kube-vip is used for two separate purposes in this cluster:

| Purpose                   | IP / Range                      | Implementation                                        |
| ------------------------- | ------------------------------- | ----------------------------------------------------- |
| Kubernetes API HA         | `192.168.30.250`                | Existing kube-vip static pods                         |
| Service LoadBalancer VIPs | `192.168.30.200-192.168.30.219` | kube-vip services DaemonSet + kube-vip cloud provider |

The existing API VIP static pod configuration was left unchanged.

A separate `kube-vip-services` DaemonSet was deployed for service LoadBalancer advertisement with:

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

This was expected and confirmed that traffic reached Traefik successfully. After the application Ingress was applied, the application became available through:

```text
http://ops.indetechs.local
```

For local browser access, the client machine must resolve the hostname to the Traefik LoadBalancer IP:

```text
192.168.30.200 ops.indetechs.local
```

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

## Storage Notes

Persistent application storage is provided by the NFS CSI driver using the default `nfs-csi` StorageClass.

The PostgreSQL database tier uses a PersistentVolumeClaim backed by the NFS server:

```text
NFS server: 192.168.32.10
Export: /srv/nfs/k8s
StorageClass: nfs-csi
PVC: postgres-data-ops-database-0
```

The NFS StorageClass uses dynamic provisioning and `Retain` reclaim policy.

## Design Decisions and Trade-offs

### Ubuntu Server 24.04 LTS

Ubuntu Server 24.04 LTS was selected because it provides a stable, long-term-supported Linux base with good Kubernetes, containerd, and cloud-native ecosystem compatibility. It is widely used in production and has predictable package/security maintenance.

### Canal CNI

Canal was selected because it combines Flannel-style pod networking with Calico NetworkPolicy support. This is a practical fit for a small local Kubernetes cluster where simple routing and working NetworkPolicy enforcement are both required.

### NFS CSI Storage

NFS CSI was selected for persistent storage because the assignment environment is local and VM-based. A dedicated NFS VM keeps storage traffic separate from management traffic using the isolated storage subnet. This provides simple dynamic provisioning and enough persistence for the three-tier application.

The main limitation is that a single NFS server is not fully redundant. For a larger production deployment, Longhorn or Rook/Ceph would be considered for replicated distributed storage.

### kube-vip LoadBalancer

kube-vip was already used for Kubernetes API high availability, so it was extended to support LoadBalancer services. This avoids introducing a second load-balancer technology such as MetalLB and keeps the design consistent.

### Traefik API Gateway

Traefik was selected as the API gateway because it integrates cleanly with Kubernetes Ingress resources and can be exposed using a private kube-vip LoadBalancer IP. OPNsense remains the network edge firewall and VPN boundary, while Traefik handles HTTP routing inside the Kubernetes platform.

## Notes

kube-vip was initially deployed only for Kubernetes API high availability through the API VIP `192.168.30.250`.

During Phase 3 preparation, kube-vip was extended to support Kubernetes `Service` objects of type `LoadBalancer`. This was implemented using a separate service-only kube-vip DaemonSet and the kube-vip cloud provider. The LoadBalancer IP pool is `192.168.30.200-192.168.30.219`.

Traefik is deployed as the cluster API gateway using a kube-vip LoadBalancer IP. The Phase 3 application is exposed through Traefik rather than directly through NodePort services.

The Phase 2 NetworkPolicies and Pod Disruption Budgets were created in advance for the three-tier application. Their runtime behavior is validated in Phase 3 after deploying frontend, backend, and database pods using the expected labels.

## Future Improvements

The mandatory core phases have been completed. The following items are planned as future improvements under the optional extension phases:

* Add Terraform or Ansible automation for VM provisioning and full cluster rebuilds
* Add Prometheus and Grafana for deeper observability
* Add centralized logging with Loki or an equivalent stack
* Add scheduled PostgreSQL backup automation
* Define and test RTO/RPO targets
* Add load testing and performance analysis
* Add Pod Security Admission profiles
* Add CI/CD for automated image builds and Kubernetes deployment
* Add automated rollback for failed deployments
* Add more detailed operational runbooks for node replacement, scaling, backup, and recovery
