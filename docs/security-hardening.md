# Security Hardening

## Overview

This document describes the security controls applied to the KVM virtual machines, Kubernetes cluster, storage network, and deployed 3-tier application.

The environment is a private local lab. It is not intentionally exposed directly to the public Internet. Administrative and application access is restricted to the private management network and WireGuard VPN path through OPNsense.

Security controls implemented include:

* SSH hardening on all Linux VMs
* non-root administrative user with sudo
* private management network
* isolated storage network
* OPNsense firewall and WireGuard VPN boundary
* Kubernetes namespace separation
* ResourceQuota and LimitRange
* default-deny NetworkPolicies
* allow-list NetworkPolicies between application tiers
* Pod Disruption Budgets
* Kubernetes Secrets for sensitive application configuration
* Traefik API gateway instead of direct pod exposure

## SSH Hardening

A dedicated administrative user is used on all VMs:

```text
anik
```

The `anik` user is a member of the `sudo` group and performs privileged work through sudo.

Direct root SSH login is disabled. Password authentication is disabled. SSH key authentication is required.

## SSH Settings

The following settings are enforced on all Kubernetes and storage VMs:

```text
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

This means:

* SSH key authentication is required.
* Password-based login is disabled.
* Direct root SSH login is disabled.
* Empty passwords are not allowed.
* X11 forwarding is disabled.
* Brute-force attempts are limited through `MaxAuthTries`.
* Idle sessions are controlled through client keepalive settings.

## SSH Verification

Effective SSH configuration can be checked with:

```bash
sudo sshd -T | egrep 'pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin|permitemptypasswords|x11forwarding|maxauthtries|clientaliveinterval|clientalivecountmax'
```

Expected output includes:

```text
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
permitrootlogin no
permitemptypasswords no
x11forwarding no
maxauthtries 3
clientaliveinterval 300
clientalivecountmax 2
```

Password-only login was tested by forcing SSH to avoid public-key authentication:

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password anik@<VM_IP>
```

Expected result:

```text
Permission denied
```

## Administrative Permissions

Privileged system access is performed through the non-root `anik` user with sudo.

Verification commands:

```bash
id anik
groups anik
sudo -l -U anik
```

Expected sudo permission:

```text
(ALL : ALL) ALL
```

This avoids direct root administration over SSH while still allowing controlled administrative work.

## Network Boundary Security

OPNsense provides the main network boundary for the lab.

The management subnet is:

```text
192.168.30.0/24
```

This subnet is used for:

* SSH access to VMs
* Kubernetes API access
* Headlamp dashboard access
* Traefik application access
* general node administration

Remote access into this private subnet is provided through WireGuard VPN on OPNsense. Kubernetes nodes and application services are not intentionally exposed directly to the public Internet.

The intended access model is:

```text
Admin / VPN Client
  -> OPNsense / WireGuard
  -> Private management network
  -> Kubernetes API, SSH, Headlamp, Traefik
```

## Storage Network Isolation

Persistent storage traffic uses a separate storage subnet:

```text
192.168.32.0/24
```

The NFS server uses:

```text
192.168.32.10:/srv/nfs/k8s
```

Kubernetes nodes mount NFS-backed volumes through their storage interfaces. These storage interfaces do not have a default gateway.

This limits the storage network to node-to-NFS communication and prevents it from becoming a general-purpose routed network.

The NFS export is restricted to the storage subnet:

```text
/srv/nfs/k8s 192.168.32.0/24(rw,sync,no_subtree_check,no_root_squash)
```

The lab currently uses `no_root_squash` to avoid UID/GID permission issues during CSI dynamic provisioning. In a stricter production deployment, this would be reviewed and replaced with tighter export permissions, `root_squash` where compatible, and workload-specific security contexts.

## Kubernetes Namespace Security

The production application runs in:

```text
app-prod
```

The production application namespace uses:

* `LimitRange`
* `ResourceQuota`
* default-deny NetworkPolicy
* allow-list NetworkPolicies
* Pod Disruption Budgets

Primary manifest:

```text
manifests/security/cluster-security.yaml
```

The namespace is labeled by environment:

```text
environment=prod
```

Verification:

```bash
kubectl get namespace app-prod --show-labels
kubectl get limitrange,resourcequota -n app-prod
kubectl get networkpolicy -n app-prod
kubectl get pdb -n app-prod
```

## Resource Controls

A `LimitRange` provides default CPU and memory requests and limits for containers in the `app-prod` namespace.

A `ResourceQuota` prevents the namespace from consuming unlimited cluster resources.

Configured quota:

```text
pods: 20
requests.cpu: 2
requests.memory: 2Gi
limits.cpu: 4
limits.memory: 4Gi
```

Application workloads also define resource requests and limits in their manifests. The namespace defaults provide an additional safety net.

Verification:

```bash
kubectl describe limitrange -n app-prod
kubectl describe resourcequota -n app-prod
kubectl -n app-prod get pods
```

## NetworkPolicy Model

NetworkPolicies are used to enforce tier isolation for the 3-tier application.

The intended traffic model is:

```text
traefik -> frontend    allowed on TCP 8080
frontend -> backend    allowed on TCP 8080
backend  -> database   allowed on TCP 5432
frontend -> database   blocked
all other app traffic  denied by default
DNS egress             allowed
```

Created policies include:

```text
default-deny-ingress-egress
allow-dns-egress
allow-frontend-to-backend
allow-frontend-egress-to-backend
allow-backend-to-database
allow-backend-egress-to-database
allow-traefik-to-frontend
```

The NetworkPolicies were created during Phase 2 and validated during Phase 3 after deploying the frontend, backend, and database pods with the expected labels.

Expected application pod labels include:

```text
app.kubernetes.io/component=frontend
app.kubernetes.io/component=backend
app.kubernetes.io/component=database
```

Verification commands:

```bash
kubectl get networkpolicy -n app-prod
kubectl describe networkpolicy -n app-prod
kubectl -n app-prod get pods --show-labels
```

The important security outcome is that external HTTP traffic enters through Traefik, frontend pods can talk to backend pods, backend pods can talk to the database, and frontend pods cannot directly access the database.

## Application Exposure Security

The application is exposed through Traefik rather than direct pod or database access.

Current application flow:

```text
Admin / VPN Client
  -> Traefik LoadBalancer IP: 192.168.30.200
  -> Ingress: ops.indetechs.local
  -> ops-frontend Service
  -> ops-backend Service
  -> ops-database Service
```

The backend and database services are internal `ClusterIP` services. They are not exposed directly outside the cluster.

Traefik is exposed on the private management subnet using kube-vip LoadBalancer support. Access is limited to the private network/VPN path.

Verification:

```bash
kubectl -n traefik get svc -o wide
kubectl -n app-prod get ingress -o wide
kubectl -n app-prod get svc -o wide
```

## Secrets Management

Sensitive application values are stored in Kubernetes Secrets.

The real application Secret is created using:

```bash
bash scripts/create-phase3-secret.sh
```

The repository includes an example Secret manifest only:

```text
manifests/workloads/app-secret.example.yaml
```

Real credentials should not be committed to the Git repository.

Verification:

```bash
kubectl -n app-prod get secret
```

In a stricter production environment, static Kubernetes Secrets would be replaced or integrated with an external secrets manager.

## Pod Disruption Budgets

Pod Disruption Budgets are configured for the application tiers:

```text
frontend-pdb
backend-pdb
database-pdb
```

The frontend and backend run multiple replicas, so their PDBs help maintain availability during voluntary disruptions such as node drain operations.

The database PDB protects the single PostgreSQL pod from voluntary eviction. However, the database tier is not highly available because it runs as a single PostgreSQL replica. The database data is persistent through the NFS-backed PVC, but the database service itself is not replicated.

Verification:

```bash
kubectl get pdb -n app-prod
kubectl describe pdb -n app-prod
```

## Dashboard Security

Headlamp is deployed for visual cluster inspection.

Headlamp is exposed only on the private management subnet and is accessed through the VPN/private network path. It is not intentionally exposed directly to the public Internet.

The current lab setup uses a Headlamp service account token for authentication. In a stricter production deployment, RBAC should be reduced to least-privilege access and the dashboard should be placed behind authenticated HTTPS access.

## TLS Status and Future Improvement

The current lab deployment uses HTTP for application access on the private management network only.

This is acceptable for the local assessment environment because:

* application access is private,
* access requires the management network or WireGuard VPN path,
* OPNsense controls the network boundary,
* backend and database services are not directly exposed.

For a stricter production deployment, TLS would be added using a re-encryption model:

```text
Client / VPN
  -> HTTPS
  -> OPNsense reverse proxy / edge TLS termination
  -> HTTPS
  -> Traefik LoadBalancer IP: 192.168.30.200
  -> Kubernetes Ingress
  -> Application services
```

In this model, OPNsense would act as the edge TLS endpoint and policy boundary, while Traefik would continue to act as the Kubernetes-native gateway inside the cluster. The OPNsense-to-Traefik hop would also use HTTPS to avoid plain HTTP between the firewall and Kubernetes gateway.

This was left as future work because TLS hardening belongs to the optional production-hardening scope.

## Security Verification Commands

General security/resource checks:

```bash
kubectl get limitrange,resourcequota,networkpolicy,pdb -n app-prod
kubectl describe networkpolicy -n app-prod
kubectl -n app-prod get pods --show-labels
kubectl -n app-prod get svc -o wide
kubectl -n traefik get svc -o wide
```

SSH checks on each VM:

```bash
sudo sshd -T | egrep 'pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin|permitemptypasswords|x11forwarding|maxauthtries|clientaliveinterval|clientalivecountmax'
```

Storage checks:

```bash
showmount -e 192.168.32.10
kubectl get storageclass,pv,pvc -A
```

Application access checks:

```bash
curl -H 'Host: ops.indetechs.local' http://192.168.30.200/
curl -H 'Host: ops.indetechs.local' http://192.168.30.200/api/tasks
```

## Known Limitations

The current lab security model has the following limitations:

* All VMs run on a single physical Proxmox host, so there is no physical-host fault tolerance.
* NFS storage is persistent but depends on a single NFS VM.
* The NFS export currently uses `no_root_squash` for lab compatibility.
* PostgreSQL runs as a single StatefulSet replica, so database persistence is provided but database high availability is not.
* TLS is not enabled in the current lab implementation.
* Headlamp uses a service account token and should be restricted further in production.
* Full Pod Security Admission enforcement is planned as future hardening.

## Future Hardening Improvements

Planned hardening improvements include:

* Enable TLS re-encryption using OPNsense and Traefik.
* Add Pod Security Admission with `restricted` policies where compatible.
* Add least-privilege RBAC for Headlamp.
* Add centralized audit logging.
* Add image vulnerability scanning in CI/CD.
* Replace static Kubernetes Secrets with an external secrets manager.
* Add automated PostgreSQL backups and restore testing.
* Replace single NFS storage with replicated storage such as Longhorn or Rook/Ceph.
* Add host-level firewall rules to further restrict traffic by role.
* Add automated configuration management with Ansible or Terraform.
