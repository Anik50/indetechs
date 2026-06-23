#!/usr/bin/env bash
set -euo pipefail

echo "== Hostname =="
hostname

echo
echo "== Kernel modules =="
lsmod | grep -E 'overlay|br_netfilter' || true

echo
echo "== Sysctl =="
sysctl net.bridge.bridge-nf-call-iptables || true
sysctl net.bridge.bridge-nf-call-ip6tables || true
sysctl net.ipv4.ip_forward || true

echo
echo "== Swap =="
swapon --show || true

echo
echo "== Containerd =="
systemctl is-active containerd || true
containerd --version || true

echo
echo "== Kubernetes packages held =="
apt-mark showhold | grep -E 'kubelet|kubeadm|kubectl' || true

echo
echo "== SSH effective config =="
sudo sshd -T | egrep 'pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin|permitemptypasswords|x11forwarding|maxauthtries|clientaliveinterval|clientalivecountmax' || true
