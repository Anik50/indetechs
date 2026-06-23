# Security Hardening

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

## Verification

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

## Kubernetes Namespace Security

The production application namespace uses:

- `LimitRange`
- `ResourceQuota`
- Default deny NetworkPolicy
- Allow-list NetworkPolicies
- Pod Disruption Budgets

Manifest:

```text
manifests/security/cluster-security.yaml
```

## NetworkPolicy Model

```text
frontend -> backend     allowed on TCP 8080
backend  -> database    allowed on TCP 5432
frontend -> database    blocked
all other app traffic   denied by default
DNS egress              allowed
```

## Notes

The NetworkPolicies are implemented before the Phase 3 application deployment. Runtime enforcement will be validated after deploying pods with these labels:

```text
app.kubernetes.io/component=frontend
app.kubernetes.io/component=backend
app.kubernetes.io/component=database
```
