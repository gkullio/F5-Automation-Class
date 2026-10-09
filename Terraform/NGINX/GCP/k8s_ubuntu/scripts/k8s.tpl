#!/bin/bash
set -euo pipefail

# --- kernel modules + sysctl ---
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# --- disable swap ---
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# --- containerd ---
apt-get update
apt-get upgrade -y
apt-get install -y containerd conntrack net-tools
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# --- k8s apt repo (v1.31) ---
apt-get install -y apt-transport-https ca-certificates curl gpg
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# --- init control plane ---
kubeadm init --pod-network-cidr=10.244.0.0/16

# --- kubeconfig for the default user ---
mkdir -p /home/${username}/.kube
cp -i /etc/kubernetes/admin.conf /home/${username}/.kube/config
chown ${username}:${username} /home/${username}/.kube/config

# --- CNI (Flannel) ---
su - ${username} -c "kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"

# allow scheduling on control-plane node (single-node lab)
sleep 15
su - ${username} -c "kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true"

# --- metrics-server (required for HPA) ---
su - ${username} -c "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"

# wait for the deployment object to exist before patching it
sleep 10
su - ${username} -c "kubectl -n kube-system patch deployment metrics-server --type='json' -p='[{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/args/-\",\"value\":\"--kubelet-insecure-tls\"}]'"

# wait for metrics-server to actually come up before applying the HPA
su - ${username} -c "kubectl -n kube-system wait --for=condition=available --timeout=120s deployment/metrics-server"

# --- helm ---
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# --- generate reusable join command for workers ---

kubeadm token create --print-join-command > /home/${username}/join-command.sh
chmod +x /home/${username}/join-command.sh

echo "Control plane setup complete. Join command saved to /home/${username}/join-command.sh"