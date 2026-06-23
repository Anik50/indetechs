# Network Topology

## Proxmox Bridges

| Bridge | Purpose |
|---|---|
| `vmbr0` | WAN / upstream side used by OPNsense |
| `vmbr1` | Private management network |
| `vmbr2` | Isolated Kubernetes storage network |

## Networks

| Network | Subnet | Purpose |
|---|---:|---|
| Management / private access network | `192.168.30.0/24` | SSH, Kubernetes API, node management, dashboard access |
| Storage network | `192.168.32.0/24` | NFS storage traffic |
| Pod network | `10.244.0.0/16` | Kubernetes pod networking through Canal |
| Service network | `10.96.0.0/12` | Kubernetes ClusterIP services |

## Static IP Plan

| Host | Management IP | Storage IP |
|---|---:|---:|
| `kubemaster-1` | `192.168.30.240` | `192.168.32.11` |
| `kubemaster-2` | `192.168.30.241` | `192.168.32.12` |
| `kubemaster-3` | `192.168.30.242` | `192.168.32.13` |
| `kubeworker-1` | `192.168.30.243` | `192.168.32.21` |
| `kubeworker-2` | `192.168.30.244` | `192.168.32.22` |
| `nfs` | `192.168.30.235` | `192.168.32.10` |
| Kubernetes API VIP | `192.168.30.250` | N/A |

## Topology Diagram

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
     ---------------------------------------------------------
     |            |            |            |           |     |
kubemaster-1  kubemaster-2  kubemaster-3  worker-1  worker-2  nfs
192.168.30.240 .241         .242          .243      .244      .235
     |            |            |            |           |      |
     ----------------------------------------------------------
                         Kubernetes API VIP
                          192.168.30.250


                  Isolated Storage Network
                      192.168.32.0/24
                              vmbr2
                                |
     ---------------------------------------------------------
     |            |            |            |           |     |
kubemaster-1  kubemaster-2  kubemaster-3  worker-1  worker-2  nfs
192.168.32.11 .12          .13           .21       .22       .10
                                                               |
                                                       /srv/nfs/k8s
```

## Design Notes

The management network carries SSH, Kubernetes API, Headlamp dashboard access, and general node management traffic. Remote administrative access to this private subnet is provided through the WireGuard VPN configured on OPNsense; these services are not intended to be exposed directly to the public Internet.

The storage network is isolated and only used for NFS traffic between Kubernetes nodes and the storage VM. Storage interfaces do not have a default gateway. This reduces unnecessary exposure of the NFS service and separates storage traffic from management/application traffic.