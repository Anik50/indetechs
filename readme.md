# Indetechs Kubernetes Technical Assessment

## Production-Grade Kubernetes Cluster on KVM with Persistent Storage

This repository documents and stores the configuration, manifests, scripts, and evidence for a local production-style Kubernetes environment built for the Indetechs Software Limited IT Operations Officer technical assessment.

The environment is deployed on **Proxmox VE using KVM/QEMU virtual machines**. **OPNsense** provides routing and firewall functionality, with **WireGuard VPN** access into the private management subnet. Kubernetes is deployed using **kubeadm** with three control-plane nodes, two worker nodes, a dedicated NFS storage VM, Canal CNI, kube-vip for the Kubernetes API virtual IP, kube-vip LoadBalancer support, Traefik API gateway, Metrics Server, Headlamp dashboard, NFS CSI dynamic storage provisioning, and a containerized three-tier application.

The mandatory core phases are complete. Optional observability work using **ECK-managed Elasticsearch, Kibana, and Filebeat** was prepared and partially validated. Elasticsearch reached a running state, while Kibana was scheduled and connected to Elasticsearch but restarted due to Node.js heap memory exhaustion on the resource-limited KVM host.

Optional disaster recovery, CI/CD, private registry, and infrastructure monitoring designs are documented as future production-style extensions.

---

## Current Progress

| Phase    | Scope                                                                                                                              | Status                |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| Phase 1  | KVM infrastructure setup                                                                                                           | Complete              |
| Phase 2  | Kubernetes cluster setup, storage, networking, and security controls                                                               | Complete              |
| Phase 3  | Three-tier application deployment with Traefik, kube-vip LoadBalancer, HPA, NetworkPolicies, and NFS-backed PostgreSQL persistence | Complete              |
| Phase 4+ | Optional automation, ECK observability, DR planning, CI/CD, testing, and deeper operational runbooks                               | Partial / Future work |

---

## Assessment Coverage Status

| Area                      | Requirement / Expectation                                  | Status                             | Notes                                                                                                                            |
| ------------------------- | ---------------------------------------------------------- | ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Infrastructure            | KVM-based VM environment                                   | Complete                           | Proxmox VE with KVM/QEMU virtual machines.                                                                                       |
| Infrastructure            | Separate control-plane, worker, storage, and network roles | Complete                           | Three control-plane nodes, two worker nodes, NFS VM, and OPNsense gateway.                                                       |
| Networking                | Isolated management and storage networks                   | Complete                           | Management network uses `192.168.30.0/24`; storage network uses `192.168.32.0/24`.                                               |
| Networking                | Private access model                                       | Complete                           | Access is through OPNsense and WireGuard VPN. OPNsense management is not exposed on the WAN public IP.                           |
| Host preparation          | Kernel modules, sysctl, swap, runtime, and SSH hardening   | Complete                           | Kubernetes host prerequisites and containerd are configured.                                                                     |
| Kubernetes                | kubeadm cluster bootstrap                                  | Complete                           | Cluster created with three control-plane nodes and two workers.                                                                  |
| Kubernetes                | CNI and NetworkPolicy support                              | Complete                           | Canal CNI deployed.                                                                                                              |
| Kubernetes                | High availability API endpoint                             | Complete                           | kube-vip API VIP configured at `192.168.30.250`.                                                                                 |
| Storage                   | Dynamic persistent storage                                 | Complete                           | NFS CSI driver and default `nfs-csi` StorageClass configured.                                                                    |
| Security controls         | Namespaces, quotas, limits, NetworkPolicies, PDBs          | Complete                           | Application security controls are included in manifests.                                                                         |
| Application               | Three-tier app deployment                                  | Complete                           | Nginx frontend, Node.js backend, and PostgreSQL database deployed.                                                               |
| Application               | Persistent database validation                             | Complete                           | PostgreSQL data survived pod deletion and recreation.                                                                            |
| Exposure                  | Gateway-based application access                           | Complete                           | Traefik exposed through kube-vip LoadBalancer IP `192.168.30.200`.                                                               |
| Observability             | Kubernetes application log stack                           | Partial                            | ECK Operator and Elasticsearch deployed; Kibana connected but restarted due to Node.js heap memory exhaustion.                   |
| Observability             | Filebeat log collection                                    | Prepared                           | Filebeat ECK Beat manifest is included for Kubernetes log collection.                                                            |
| Infrastructure monitoring | Hardware, VM, and network monitoring                       | Future work                        | LibreNMS is planned for Proxmox, OPNsense, Kubernetes VMs, NFS VM, SNMP monitoring, and alerting.                                |
| Backup / DR               | PostgreSQL backup, restore, RTO, RPO                       | Documented / Future implementation | DR architecture and runbook are documented; implementation and testing are future work.                                          |
| DR Planning               | Disaster recovery architecture and failover runbook        | Documented / Future implementation | Independent Primary/DR design documented with async database replication, PBS sync, Cloudflare failover, and break-glass access. |
| Automation                | Full VM and cluster rebuild automation                     | Future work                        | Helper scripts exist, but full Terraform/Ansible automation is not complete.                                                     |
| CI/CD                     | Automated image build and deployment                       | Future work                        | Jenkins pipeline automation is planned.                                                                                          |
| Registry                  | Secure private image registry and image scanning           | Future work                        | Harbor with Trivy scanning is planned.                                                                                           |

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
     |            |            |            |            |            |
kubemaster-1  kubemaster-2  kubemaster-3  kubeworker-1 kubeworker-2  nfs
192.168.30.240 .241         .242          .243         .244          .235
     |            |            |            |            |            |
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
     |            |            |            |            |            |
kubemaster-1  kubemaster-2  kubemaster-3  kubeworker-1 kubeworker-2  nfs
192.168.32.11 .12          .13           .21          .22           .10
                                                                    |
                                                            /srv/nfs/k8s
```

The management network carries Kubernetes API access, node management, kubelet communication, kube-vip LoadBalancer traffic, and Traefik application access.

The storage network is isolated from the management network and is dedicated to NFS traffic between the Kubernetes nodes and the storage VM.

External access is intentionally private. Access enters through OPNsense and WireGuard rather than exposing Kubernetes services directly to the public internet. OPNsense administration is restricted to the private management network or VPN path and is not exposed through the WAN public IP.

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

## Optional Observability Traffic Flow

```text
Application Pods
  -> stdout / stderr container logs
  -> Node log files under /var/log/pods
  -> Filebeat ECK Beat / DaemonSet
  -> Elasticsearch
  -> Kibana
```

Filebeat is intended to run on Kubernetes nodes and collect container logs from the node log paths. Filebeat enriches logs with Kubernetes metadata and forwards them to Elasticsearch. Kibana is used to search and visualize application logs.

This observability layer is documented as an optional extension. The ECK Operator and Elasticsearch were deployed successfully, and Kibana was scheduled and connected to Elasticsearch. However, Kibana did not remain healthy because the Kibana Node.js process exhausted available heap memory on the current resource-limited KVM host.

Detailed observability notes are kept with the observability manifests:

```text
manifests/observability/elk/README.md
```

---

## Optional Disaster Recovery Planning

A disaster recovery plan is included as a future production-style extension.

The current lab is a single-site Kubernetes deployment. The DR document describes a target two-site architecture with independent Primary and DR environments. The design avoids stretched Proxmox, stretched Ceph, QDevice, and cross-site Kubernetes control planes.

Target DR model:

```text
Primary DC
  -> local OPNsense HA
  -> local hypervisor/storage
  -> local Kubernetes cluster
  -> production application services
  -> active database

DR DC
  -> local OPNsense HA
  -> local hypervisor/storage
  -> local Kubernetes cluster
  -> warm/cold application services
  -> async database replica
```

The critical cross-site flow is async database replication, with backup synchronization and controlled monitoring/admin traffic over a routed site-to-site connection.

Target objectives:

| Item             | Target                                           |
| ---------------- | ------------------------------------------------ |
| RPO              | Approximately 30 minutes                         |
| RTO              | Approximately 1–2 hours for manual DR activation |
| Failover model   | Manual or controlled failover                    |
| Site model       | Independent Primary and DR sites                 |
| Storage model    | Site-local storage only                          |
| Kubernetes model | One Kubernetes cluster per site                  |

The full DR plan and architecture diagram are documented in:

```text
docs/disaster-recovery-plan.md
screenshots/dr-architecture.png
diagrams/dr-architecture.drawio
```

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

| Component                        | Value                                                                                                               |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Kubernetes version               | `v1.36.2`                                                                                                           |
| OS                               | Ubuntu Server 24.04.4 LTS                                                                                           |
| Kernel                           | `6.8.0-124-generic`                                                                                                 |
| Container runtime                | `containerd://2.3.2`                                                                                                |
| Bootstrap method                 | `kubeadm`                                                                                                           |
| Control-plane nodes              | 3                                                                                                                   |
| Worker nodes                     | 2                                                                                                                   |
| etcd topology                    | Stacked etcd across the three control-plane nodes                                                                   |
| CNI                              | Canal                                                                                                               |
| Pod CIDR                         | `10.244.0.0/16`                                                                                                     |
| Service CIDR                     | `10.96.0.0/12`                                                                                                      |
| Kubernetes API VIP               | `192.168.30.250`                                                                                                    |
| Service LoadBalancer provider    | kube-vip                                                                                                            |
| LoadBalancer IP pool             | `192.168.30.200-192.168.30.219`                                                                                     |
| API Gateway / Ingress Controller | Traefik                                                                                                             |
| Traefik LoadBalancer IP          | `192.168.30.200`                                                                                                    |
| Storage backend                  | NFS + NFS CSI                                                                                                       |
| Default StorageClass             | `nfs-csi`                                                                                                           |
| Dashboard                        | Headlamp                                                                                                            |
| Metrics                          | Metrics Server                                                                                                      |
| Application logging              | Optional ECK-managed Elasticsearch, Kibana, and Filebeat prepared; partially validated due to local resource limits |
| Disaster recovery                | Target independent Primary/DR architecture documented as future implementation                                      |
| CI/CD and registry               | Jenkins and Harbor planned as future implementation                                                                 |

The control-plane nodes use the standard kubeadm stacked-etcd topology. This gives control-plane redundancy for the lab while keeping the architecture simpler than an external etcd cluster.

---

## Platform Components

| Component                     | Namespace / Location     | Deployment Method                     | Purpose                                                   |
| ----------------------------- | ------------------------ | ------------------------------------- | --------------------------------------------------------- |
| Canal CNI                     | `kube-system`            | Kubernetes manifests                  | Pod networking and NetworkPolicy support                  |
| kube-vip API VIP              | Control-plane static pod | Static pod                            | Highly available Kubernetes API virtual IP                |
| kube-vip service LoadBalancer | `kube-system`            | Kubernetes manifests                  | LoadBalancer IP advertisement for services                |
| kube-vip cloud provider       | `kube-system`            | Kubernetes manifests                  | Assigns service LoadBalancer IPs from the configured pool |
| NFS CSI Driver                | `kube-system`            | Helm                                  | Dynamic provisioning of NFS-backed PersistentVolumes      |
| Traefik                       | `traefik`                | Helm                                  | HTTP application gateway and Ingress controller           |
| Headlamp                      | `headlamp`               | Helm                                  | Kubernetes dashboard visibility                           |
| Metrics Server                | `kube-system`            | Kubernetes manifests / cluster add-on | Resource metrics for HPA and operational checks           |
| ECK Operator                  | `elastic-system`         | Helm                                  | Optional operator for managing Elastic Stack resources    |
| Elasticsearch                 | `elastic-stack`          | ECK Stack Helm values                 | Optional application log indexing and storage             |
| Kibana                        | `elastic-stack`          | ECK Stack Helm values                 | Optional log search and visualization                     |
| Filebeat                      | `elastic-stack`          | ECK Beat resource / DaemonSet         | Optional Kubernetes application log collection from nodes |
| Jenkins                       | External / planned       | Docker                                | Planned CI/CD automation server                           |
| Harbor                        | External / planned       | Docker Compose / Harbor installer     | Planned private image registry and vulnerability scanning |
| LibreNMS                      | External / planned       | Future implementation                 | Planned infrastructure monitoring and alerting            |

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
├── diagrams/
│   └── dr-architecture.drawio
├── docs/
│   ├── disaster-recovery-plan.md
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
│   │       ├── README.md
│   │       ├── eck-stack-values.yaml
│   │       └── filebeat.yaml
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
│   ├── all-deployments-headlamp.png
│   ├── app-frontend.png
│   ├── dr-architecture.png
│   ├── eck-observability.png
│   ├── full-cluster-metrics-server.png
│   ├── headlamp-workloads.png
│   ├── prod-namespace.png
│   ├── nodes-cluster-ready.png
│   ├── storage-pvc-pv.png
│   ├── storage-pvc-pv.png
│   └── traefik-kubevip-loadbalancer.png
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

| Document                                 | Purpose                                                                                                             |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `docs/phase-1-infrastructure.md`         | KVM, Proxmox, VM, OS, SSH, and host preparation details                                                             |
| `docs/phase-2-kubernetes-cluster.md`     | Kubernetes bootstrap, node joining, CNI, storage, and cluster controls                                              |
| `docs/phase-3-application-deployment.md` | Application deployment, service exposure, persistence, and validation                                               |
| `docs/network-topology.md`               | Management, storage, VIP, and service exposure network design                                                       |
| `docs/storage-design.md`                 | NFS server, NFS CSI, StorageClass, PVC, and persistence decisions                                                   |
| `docs/security-hardening.md`             | Infrastructure and Kubernetes hardening controls                                                                    |
| `docs/headlamp-dashboard.md`             | Dashboard deployment and operational visibility                                                                     |
| `docs/kube-vip-loadbalancer.md`          | API VIP and service LoadBalancer design                                                                             |
| `docs/traefik-api-gateway.md`            | Traefik gateway and Ingress routing                                                                                 |
| `docs/disaster-recovery-plan.md`         | Target DC/DR architecture, RPO/RTO planning, database replication, backup sync, Cloudflare failover, and DR runbook |
| `manifests/observability/elk/README.md`  | Optional ECK-managed Elasticsearch, Kibana, and Filebeat observability notes                                        |

---

## Main Manifests

| Manifest                                               | Purpose                                                         |
| ------------------------------------------------------ | --------------------------------------------------------------- |
| `manifests/storage/nfs-storageclass.yaml`              | NFS CSI StorageClass                                            |
| `manifests/storage/nfs-pvc-test.yaml`                  | NFS dynamic provisioning test                                   |
| `manifests/namespaces/app-namespaces.yaml`             | Application environment namespaces                              |
| `manifests/security/cluster-security.yaml`             | LimitRange, ResourceQuota, NetworkPolicies, and PDBs            |
| `manifests/kube-vip/kube-vip-services-ds.yaml`         | kube-vip service LoadBalancer advertisement DaemonSet           |
| `manifests/kube-vip/kubevip-ip-pool.yaml`              | kube-vip LoadBalancer IP pool ConfigMap                         |
| `manifests/traefik/traefik-values.yaml`                | Helm values used for Traefik deployment                         |
| `manifests/traefik/traefik-service.yaml`               | Captured Traefik LoadBalancer service                           |
| `manifests/traefik/traefik-ingressclass.yaml`          | Captured Traefik IngressClass                                   |
| `manifests/observability/elk/eck-stack-values.yaml`    | Optional ECK Stack Helm values for Elasticsearch and Kibana     |
| `manifests/observability/elk/filebeat.yaml`            | Optional ECK Beat resource and RBAC for Filebeat log collection |
| `manifests/workloads/kustomization.yaml`               | Kustomize entrypoint for Phase 3 workload deployment            |
| `manifests/workloads/app-config.yaml`                  | Application ConfigMap                                           |
| `manifests/workloads/app-secret.example.yaml`          | Example Secret manifest                                         |
| `manifests/workloads/database.yaml`                    | PostgreSQL StatefulSet, Service, and PVC                        |
| `manifests/workloads/backend.yaml`                     | Backend API Deployment and Service                              |
| `manifests/workloads/frontend.yaml`                    | Frontend Deployment and Service                                 |
| `manifests/workloads/frontend-hpa.yaml`                | HorizontalPodAutoscaler for frontend                            |
| `manifests/workloads/networkpolicy-allow-traefik.yaml` | NetworkPolicy allowing Traefik to reach frontend                |
| `manifests/workloads/ingress.yaml`                     | Traefik Ingress route for the application                       |

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
* Swap disabled
* Required kernel modules and sysctl settings applied

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

The application is the **Indetechs 3-Tier Operations Task Portal**. It provides a simple web interface where tasks can be created, listed, marked complete, and deleted. The application is intentionally lightweight to fit local KVM resource constraints while still demonstrating a complete frontend, backend, and database architecture.

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

## Optional ECK Observability

The project includes an optional ECK-managed observability design for centralized application logging.

| Component     | Purpose                                                | Status                                                               |
| ------------- | ------------------------------------------------------ | -------------------------------------------------------------------- |
| ECK Operator  | Manages Elastic resources inside Kubernetes            | Deployed                                                             |
| Elasticsearch | Stores and indexes application log events              | Running                                                              |
| Kibana        | Provides log search and visualization                  | Partially validated; restarted due to Node.js heap memory exhaustion |
| Filebeat      | Collects Kubernetes container logs from node log paths | Prepared as an ECK Beat resource                                     |

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

Recommended Kibana queries after the stack is fully running:

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

Important status note:

The ECK observability stack was partially validated in the final lab. The ECK Operator was deployed, and Elasticsearch reached a running state. Kibana was scheduled on `kubeworker-2` and connected to Elasticsearch, but it repeatedly restarted because the Kibana Node.js process ran out of heap memory.

Observed error:

```text
FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed - JavaScript heap out of memory
```

This means the issue was not Kubernetes scheduling or Elasticsearch connectivity. The limitation was caused by insufficient available memory for Kibana on the current KVM lab host. Therefore, ECK/Filebeat observability is documented as prepared and partially validated optional work rather than a fully completed verified component.

Detailed deployment and troubleshooting notes are documented in:

```text
manifests/observability/elk/README.md
```

---

## Optional ECK Observability Deployment

The optional observability stack is planned to be deployed using the Elastic Helm repository and the ECK Stack chart.

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

Deploy the ECK Stack values:

```bash
helm install elastic-stack elastic/eck-stack \
  -n elastic-stack \
  --create-namespace \
  -f manifests/observability/elk/eck-stack-values.yaml
```

For updates to the ECK Stack values:

```bash
helm upgrade elastic-stack elastic/eck-stack \
  -n elastic-stack \
  -f manifests/observability/elk/eck-stack-values.yaml
```

Deploy Filebeat log collection:

```bash
kubectl apply -f manifests/observability/elk/filebeat.yaml
```

Verify the ECK resources:

```bash
kubectl get pods -n elastic-system
kubectl get pods -n elastic-stack
kubectl get elasticsearch,kibana,beat -n elastic-stack
kubectl get pvc -n elastic-stack
```

Get the Kibana service:

```bash
kubectl get svc -n elastic-stack
```

Port-forward Kibana for local access:

```bash
kubectl port-forward -n elastic-stack svc/kibana-kb-http 5601:5601
```

If the service name differs, use the actual Kibana service name shown by:

```bash
kubectl get svc -n elastic-stack
```

Open Kibana locally:

```text
https://localhost:5601
```

Get the default Elasticsearch user password:

```bash
kubectl get secret -n elastic-stack elasticsearch-es-elastic-user \
  -o go-template='{{.data.elastic | base64decode}}'
```

If the secret name differs, list the generated Elastic secrets first:

```bash
kubectl get secret -n elastic-stack | grep elastic
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

Optional ECK observability verification, when sufficient resources are available:

```bash
kubectl get pods -n elastic-system
kubectl get pods -n elastic-stack
kubectl get elasticsearch,kibana,beat -n elastic-stack
kubectl get beat -n elastic-stack
kubectl get daemonset -n elastic-stack
```

Kibana query for application logs:

```text
kubernetes.namespace : "app-prod"
```

---

## Security Notes

The cluster uses a private management network and VPN-based access model. Kubernetes services are not intentionally exposed directly to the public internet.

OPNsense administration is not exposed on the WAN public IP. Web GUI and SSH access are restricted to the private management network and WireGuard VPN. WAN firewall rules do not allow access to OPNsense management ports, and public access is limited to required application or VPN endpoints only.

Security controls include:

* OPNsense firewall boundary
* WireGuard VPN access
* OPNsense GUI and SSH restricted to VPN or management networks
* No WAN exposure for OPNsense administration
* SSH hardening
* Key-based SSH authentication
* Non-root administrative user
* Kubernetes namespaces for environment separation
* ResourceQuota and LimitRange in `app-prod`
* Default-deny NetworkPolicy baseline
* Explicit tier-to-tier NetworkPolicy rules
* Traefik ingress/API gateway instead of direct pod access
* NFS storage traffic isolated on a dedicated storage subnet
* Optional application log centralization through Filebeat instead of direct node access

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

OPNsense management is restricted to VPN or private management networks. The WAN public IP is not used for OPNsense GUI or SSH administration.

### Canal CNI

Canal was selected because it combines Flannel-style pod networking with Calico NetworkPolicy support. This is a practical fit for a small local Kubernetes cluster where simple routing and working NetworkPolicy enforcement are both required.

### NFS CSI Storage

NFS CSI was selected for persistent storage because the assessment environment is local and VM-based. A dedicated NFS VM keeps storage traffic separate from management traffic using the isolated storage subnet. This provides simple dynamic provisioning and enough persistence for the three-tier application.

The main limitation is that a single NFS server is not fully redundant. For a larger production deployment, Longhorn or Rook/Ceph would be considered for replicated distributed storage.

### kube-vip LoadBalancer

kube-vip was already used for Kubernetes API high availability, so it was extended to support LoadBalancer services. This avoids introducing a second load-balancer technology and keeps the design consistent.

### Traefik API Gateway

Traefik was selected as the API gateway because it integrates cleanly with Kubernetes Ingress resources and can be exposed using a private kube-vip LoadBalancer IP. OPNsense remains the network edge firewall and VPN boundary, while Traefik handles HTTP routing inside the Kubernetes platform.

### ECK Observability

ECK-managed Elasticsearch, Kibana, and Filebeat were selected for the optional centralized logging design because they provide Kubernetes-native log collection, indexing, search, and visualization.

Filebeat is suitable for Kubernetes node-level log collection because it can run as a DaemonSet-style workload, read Kubernetes pod logs from node log paths, enrich events with Kubernetes metadata, and forward application logs into Elasticsearch.

In this submission, ECK observability is documented as an optional extension rather than a completed verified component. The ECK Operator and Elasticsearch were deployed successfully, and Kibana was able to connect to Elasticsearch. However, Kibana repeatedly restarted due to Node.js heap memory exhaustion on the resource-limited KVM host. A larger host or dedicated observability worker node would be required to complete full validation.

### Disaster Recovery Planning

A future disaster recovery design is documented separately to show how this platform could be extended beyond the current single-site lab.

The DR design uses two independent sites rather than stretched clusters. Each site has its own OPNsense HA pair, hypervisor/storage stack, Kubernetes cluster, ingress layer, and backup service. The sites are connected through routed site-to-site connectivity, with only controlled cross-site traffic such as async database replication, backup synchronization, monitoring, logging, and admin access.

This avoids WAN-sensitive designs such as stretched Proxmox, stretched Ceph, QDevice-based cross-site quorum, and cross-site Kubernetes control planes.

### Jenkins and Harbor

Jenkins and Harbor are documented as future CI/CD and private registry components.

Jenkins is planned for automated build, tag, push, scan, deploy, and rollback workflows. Harbor is planned as the private container registry for storing application images and scanning them before Kubernetes deployment.

These components are not part of the verified Phase 1–3 deployment, but they are included as a future production-style improvement path.

---

## Operational Notes

kube-vip was initially deployed only for Kubernetes API high availability through the API VIP `192.168.30.250`.

During Phase 3 preparation, kube-vip was extended to support Kubernetes Service objects of type `LoadBalancer`. This was implemented using a separate service-only kube-vip DaemonSet and the kube-vip cloud provider. The LoadBalancer IP pool is `192.168.30.200-192.168.30.219`.

Traefik is deployed as the cluster API gateway using a kube-vip LoadBalancer IP. The Phase 3 application is exposed through Traefik rather than directly through NodePort services.

The Phase 2 NetworkPolicies and Pod Disruption Budgets were created in advance for the three-tier application. Their runtime behavior is validated in Phase 3 after deploying frontend, backend, and database pods using the expected labels.

ECK observability is treated as an optional extension phase. The prepared design deploys Elasticsearch and Kibana through the ECK Stack Helm chart, and Filebeat is deployed as an ECK Beat resource to collect application logs from Kubernetes nodes.

LibreNMS is planned as a future infrastructure monitoring and alerting layer for the Proxmox host, OPNsense, Kubernetes VMs, and the NFS storage VM. This would complement ECK/Filebeat by monitoring host, device, network interface, disk, and reachability health outside Kubernetes.

Disaster recovery is documented as a target future architecture rather than a completed implementation. The DR plan describes independent Primary and DR sites, async database replication, backup synchronization, Cloudflare failover, break-glass access, and failover/failback runbooks.

---

## Optional CI/CD and Private Registry Preparation

Jenkins and Harbor are planned as the future CI/CD and private container registry components for this lab.

The intended CI/CD flow is:

```text
Developer / Git Repository
  -> Jenkins pipeline
  -> Build frontend, backend, and database images
  -> Push images to Harbor private registry
  -> Scan images in Harbor
  -> Deploy approved images to Kubernetes
```

| Component       | Purpose                                                              | Status                |
| --------------- | -------------------------------------------------------------------- | --------------------- |
| Jenkins         | CI/CD automation server for image builds and deployment pipelines    | Planned / Future work |
| Harbor          | Private container registry for storing and scanning container images | Planned / Future work |
| Trivy in Harbor | Vulnerability scanning for pushed images                             | Planned / Future work |

---

### Jenkins Installation with Docker

Create a persistent Jenkins home directory:

```bash
sudo mkdir -p /var/jenkins_home
sudo chown -R 1000:1000 /var/jenkins_home
```

Run Jenkins as a Docker container:

```bash
docker run -d \
  --name jenkins \
  --restart=always \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /var/jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts
```

Check that Jenkins is running:

```bash
docker ps | grep jenkins
```

Get the initial Jenkins admin password:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Open Jenkins in a browser:

```text
http://<jenkins-host-ip>:8080
```

After login, install recommended plugins and create the first admin user.

---

### Harbor Installation for Private Image Registry

Harbor is planned as the private Docker image registry for this project. It will store application images securely and provide vulnerability scanning before images are deployed to Kubernetes.

Install required packages on the Harbor host:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin wget tar
```

Create an installation directory:

```bash
sudo mkdir -p /opt/harbor
cd /opt/harbor
```

Download the Harbor offline installer from the Harbor releases page. Replace the version below with the version selected for the lab:

```bash
HARBOR_VERSION=<harbor-version>

wget https://github.com/goharbor/harbor/releases/download/v${HARBOR_VERSION}/harbor-offline-installer-v${HARBOR_VERSION}.tgz
tar xzf harbor-offline-installer-v${HARBOR_VERSION}.tgz
cd harbor
```

Create the Harbor configuration file:

```bash
cp harbor.yml.tmpl harbor.yml
```

Edit the configuration:

```bash
nano harbor.yml
```

Important values to set:

```yaml
hostname: harbor.indetechs.local

harbor_admin_password: ChangeMeStrongPassword

data_volume: /data
```

For a production-style deployment, Harbor should use HTTPS. In this local lab, the hostname can be mapped through local DNS or `/etc/hosts`.

Install Harbor with Trivy vulnerability scanning enabled:

```bash
sudo ./install.sh --with-trivy
```

Verify Harbor containers:

```bash
docker compose ps
```

Access Harbor:

```text
https://harbor.indetechs.local
```

Default username:

```text
admin
```

Use the password configured in `harbor.yml`.

---

### Example Image Push to Harbor

Create a Harbor project named:

```text
indetechs
```

Login to Harbor:

```bash
docker login harbor.indetechs.local
```

Tag an application image for Harbor:

```bash
docker tag docker.io/anik50/ops-backend:v3 harbor.indetechs.local/indetechs/ops-backend:v3
```

Push the image:

```bash
docker push harbor.indetechs.local/indetechs/ops-backend:v3
```

The same approach can be used for the frontend and database images:

```bash
docker tag docker.io/anik50/ops-frontend:v3 harbor.indetechs.local/indetechs/ops-frontend:v3
docker tag docker.io/anik50/ops-database:v3 harbor.indetechs.local/indetechs/ops-database:v3

docker push harbor.indetechs.local/indetechs/ops-frontend:v3
docker push harbor.indetechs.local/indetechs/ops-database:v3
```

After images are pushed, Harbor can scan them for vulnerabilities before they are used in Kubernetes manifests.

---

### Future Jenkins Pipeline Direction

The planned Jenkins pipeline will:

1. pull source code from Git;
2. build frontend, backend, and database container images;
3. tag images with a version or commit hash;
4. push images to Harbor;
5. trigger or verify Harbor vulnerability scans;
6. deploy approved images to Kubernetes using `kubectl` or Kustomize;
7. provide rollback support if deployment fails.

This CI/CD work is documented as future improvement and is not part of the verified mandatory Phase 1–3 deployment.

---

## Known Limitations

The mandatory core phases have been completed and verified. The following limitations remain:

* The NFS server is a single storage server and is not fully redundant.
* Full VM provisioning is documented, but not yet fully automated with Terraform or Ansible.
* ECK observability was prepared and partially validated, with Elasticsearch running successfully.
* Kibana was scheduled and connected to Elasticsearch, but restarted due to Node.js heap memory exhaustion on the resource-limited KVM host.
* Full Filebeat-to-Elasticsearch validation should be completed on a larger host or dedicated observability worker node.
* The documented two-site DR architecture is planned but not yet implemented.
* Scheduled PostgreSQL backup automation is not yet implemented.
* RTO and RPO targets are documented as planning targets but are not yet formally tested.
* DR failover and failback runbooks are documented but not yet rehearsed in a live DR environment.
* Load testing and performance analysis are not yet complete.
* Jenkins CI/CD automation is planned but not yet implemented.
* Harbor private registry and image vulnerability scanning are planned but not yet implemented.
* CI/CD and automated rollback are planned but not yet implemented.
* LibreNMS infrastructure monitoring and alerting is planned but not yet implemented.
* More detailed operational runbooks are planned for node replacement, scaling, backup, and recovery.

---

## Future Improvements

The mandatory core phases have been completed. The following items are planned as future improvements under the optional extension phases:

* Add Terraform or Ansible automation for VM provisioning and full cluster rebuilds
* Complete ECK-managed Elasticsearch, Kibana, and Filebeat validation on a larger lab host
* Implement the documented DR plan with a separate DR site, async database replication, backup synchronization, Cloudflare failover, and tested failover/failback runbooks
* Add scheduled PostgreSQL backup automation
* Define and test final RTO/RPO targets
* Add LibreNMS for Proxmox, OPNsense, Kubernetes VM, NFS VM, SNMP monitoring, and infrastructure alerting
* Add Jenkins for CI/CD pipeline automation
* Add Harbor as a private container registry with vulnerability scanning
* Build a Jenkins pipeline to build, scan, push, and deploy application images through Harbor
* Add load testing and performance analysis
* Add Pod Security Admission profiles
* Add CI/CD for automated image builds and Kubernetes deployment
* Add automated rollback for failed deployments
* Add more detailed operational runbooks for node replacement, scaling, backup, and recovery
