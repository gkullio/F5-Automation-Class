#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="$(eval echo ~${SUDO_USER:-$USER})"
export KUBECONFIG="${USER_HOME}/.kube/config"

echo "=== [1/5] Waiting for cloud-init to complete ==="
cloud-init status --wait

echo "=== [2/5] Waiting for Kubernetes control plane ==="
for i in $(seq 1 60); do
  if kubectl get nodes &>/dev/null; then
    echo "Kubernetes API server is responding."
    break
  fi
  echo "Waiting for Kubernetes API... ($i/60)"
  sleep 3
done

echo "=== [3/5] Setting up NGINX Gateway Fabric (Plus) ==="
JWT_PATH="${USER_HOME}/secrets/nginx-repo.jwt"
if [ ! -f "$JWT_PATH" ]; then
  echo "Error: $JWT_PATH not found. NGINX Gateway Fabric (Plus) requires the NGINX JWT."
  exit 1
fi

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
kubectl create namespace nginx-gateway --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry nginx-plus-registry-secret \
  --docker-server=private-registry.nginx.com \
  --docker-username="$(cat "$JWT_PATH")" \
  --docker-password=none \
  -n nginx-gateway \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic nplus-license \
  --from-file=license.jwt="$JWT_PATH" \
  -n nginx-gateway \
  --dry-run=client -o yaml | kubectl apply -f -

# Data plane runs as a DaemonSet bound to host port 80 so BIG-IP can reach it
# on any of the internal NIC IPs (10.245.2.99 - 10.245.2.105)
helm upgrade --install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --set nginx.plus=true \
  --set nginx.image.repository=private-registry.nginx.com/nginx-gateway-fabric/nginx-plus \
  --set nginx.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.kind=daemonSet \
  --set nginx.service.type=NodePort \
  --set nginx.container.hostPorts[0].port=80 \
  --set nginx.container.hostPorts[0].containerPort=80 \
  --wait

echo "=== [4/5] Deploying Gateway and Application Manifests ==="
MANIFESTS_DIR="${USER_HOME}/manifests"
if [ -d "$MANIFESTS_DIR" ]; then
  kubectl apply -k "$MANIFESTS_DIR"
fi

echo "=== [5/5] Verifying Gateway and Routes ==="
kubectl -n nginx-gateway wait --for=condition=Programmed --timeout=180s gateway/lab-gateway || true
kubectl -n nginx-gateway get gateway,pods,svc || true
kubectl -n demoapp get pods,svc,httproute || true
kubectl -n dvga get pods,svc,httproute || true
kubectl -n dvwa get pods,svc,httproute || true
kubectl -n juice-shop get pods,svc,httproute || true

echo "=== All installations completed successfully! ==="
