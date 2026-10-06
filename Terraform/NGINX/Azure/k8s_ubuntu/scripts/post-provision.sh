#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="$(eval echo ~${SUDO_USER:-$USER})"
export KUBECONFIG="${USER_HOME}/.kube/config"

echo "=== [1/6] Waiting for cloud-init to complete ==="
cloud-init status --wait

echo "=== [2/6] Waiting for Kubernetes control plane ==="
for i in $(seq 1 60); do
  if kubectl get nodes &>/dev/null; then
    echo "Kubernetes API server is responding."
    break
  fi
  echo "Waiting for Kubernetes API... ($i/60)"
  sleep 3
done

echo "=== [3/6] Installing ingress-nginx controller ==="
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/baremetal/deploy.yaml
kubectl -n ingress-nginx wait --for=condition=available --timeout=180s deployment/ingress-nginx-controller

# Enable hostNetwork for baremetal/VM direct port exposure
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  -p '{"spec":{"template":{"spec":{"hostNetwork":true,"dnsPolicy":"ClusterFirstWithHostNet"}}}}'

kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=120s

# Wait for admission webhook endpoint
echo "Waiting for admission webhook..."
for i in $(seq 1 30); do
  ep=$(kubectl -n ingress-nginx get endpoints ingress-nginx-controller-admission -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
  if [ -n "$ep" ]; then
    echo "Admission webhook endpoint ready: $ep"
    break
  fi
  sleep 3
done

echo "=== [4/6] Deploying Application Manifests ==="
MANIFESTS_DIR="${USER_HOME}/manifests"
if [ -d "$MANIFESTS_DIR" ]; then
  kubectl apply -k "$MANIFESTS_DIR"
  echo "Checking deployed application resources:"
  kubectl -n demoapp get pods,svc,ingress || true
  kubectl -n dvga get pods,svc,ingress || true
  kubectl -n dvwa get pods,svc,ingress || true
  kubectl -n juice-shop get pods,svc,ingress || true
fi

echo "=== [5/6] Setting up NGINX Ingress Controller (Plus) ==="
JWT_PATH="${USER_HOME}/secrets/nginx-repo.jwt"
if [ -f "$JWT_PATH" ]; then
  kubectl create namespace nginx-ingress --dry-run=client -o yaml | kubectl apply -f -

  kubectl create secret docker-registry regcred \
    --docker-server=private-registry.nginx.com \
    --docker-username="$(cat "$JWT_PATH")" \
    --docker-password=none \
    -n nginx-ingress \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl create secret generic nplus-license \
    --from-file=license.jwt="$JWT_PATH" \
    -n nginx-ingress \
    --dry-run=client -o yaml | kubectl apply -f -

  helm upgrade --install nic oci://ghcr.io/nginx/charts/nginx-ingress \
    --namespace nginx-ingress \
    --set controller.ingressClass.name=nginx-plus \
    --set controller.nginxplus=true \
    --set controller.image.repository=private-registry.nginx.com/nginx-ic/nginx-plus-ingress \
    --set controller.image.tag=5.5.4 \
    --set controller.serviceAccount.imagePullSecretName=regcred \
    --set controller.mgmt.licenseTokenSecretName=nplus-license
else
  echo "Warning: $JWT_PATH not found. Skipping NGINX Ingress Controller installation."
fi

echo "=== [6/6] Setting up NGINX Gateway Fabric (Plus) ==="
if [ -f "$JWT_PATH" ]; then
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

  helm upgrade --install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
    --namespace nginx-gateway \
    --set nginx.plus=true \
    --set nginx.image.repository=private-registry.nginx.com/nginx-gateway-fabric/nginx-plus \
    --set nginx.imagePullSecret=nginx-plus-registry-secret
fi

echo "=== All installations completed successfully! ==="
