resource "null_resource" "apply_manifests" {
  depends_on = [google_compute_instance.k8s_vm]

  connection {
    type        = "ssh"
    host        = google_compute_address.management_ip.address
    user        = "gage"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "mkdir -p /home/gage/manifests/demoapp",
      "mkdir -p /home/gage/manifests/dvwa",
      "mkdir -p /home/gage/manifests/dvga",
      "mkdir -p /home/gage/manifests/juice-shop",
      "mkdir -p /home/gage/secrets"
    ]
  }

  provisioner "file" {
    source      = "secrets"
    destination = "/home/gage/"
  }

  provisioner "file" {
    source      = "manifests/demoapp"
    destination = "/home/gage/manifests/"
  }

  provisioner "file" {
    source      = "manifests/dvga"
    destination = "/home/gage/manifests/"
  }

  provisioner "file" {
    source      = "manifests/dvwa"
    destination = "/home/gage/manifests/"
  }

  provisioner "file" {
    source      = "manifests/juice-shop"
    destination = "/home/gage/manifests/"
  }

  provisioner "remote-exec" {
    inline = [
      "export KUBECONFIG=/home/gage/.kube/config",

      # install ingress-nginx
      "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/baremetal/deploy.yaml",
      "kubectl -n ingress-nginx wait --for=condition=available --timeout=180s deployment/ingress-nginx-controller",
      "kubectl patch deployment ingress-nginx-controller -n ingress-nginx -p '{\"spec\":{\"template\":{\"spec\":{\"hostNetwork\":true,\"dnsPolicy\":\"ClusterFirstWithHostNet\"}}}}'",

      # wait for the hostNetwork restart to fully roll out
      "kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=120s",

      # wait for the admission webhook's Service to actually have a ready backend
      "for i in $(seq 1 30); do ep=$(kubectl -n ingress-nginx get endpoints ingress-nginx-controller-admission -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null); if [ -n \"$ep\" ]; then echo \"Admission webhook endpoint ready: $ep\"; break; fi; echo \"Waiting for admission webhook endpoint... ($i/30)\"; sleep 3; done",

      # demoapp
      "kubectl apply -f /home/gage/manifests/demoapp/namespace-demoapp.yaml",
      "kubectl apply -f /home/gage/manifests/demoapp/deployment-demoapp.yaml",
      "kubectl apply -f /home/gage/manifests/demoapp/service-demoapp.yaml",
      "kubectl apply -f /home/gage/manifests/demoapp/ingress-demoapp.yaml",
      "kubectl apply -f /home/gage/manifests/demoapp/hpa-demoapp.yaml",
      "kubectl -n demoapp get pods,svc,ingress",

      # juice-shop
      "kubectl apply -f /home/gage/manifests/dvga/namespace-dvga.yaml",
      "kubectl apply -f /home/gage/manifests/dvga/deployment-dvga.yaml",
      "kubectl apply -f /home/gage/manifests/dvga/service-dvga.yaml",
      "kubectl apply -f /home/gage/manifests/dvga/ingress-dvga.yaml",
      "kubectl apply -f /home/gage/manifests/dvga/hpa-dvga.yaml",
      "kubectl -n dvga get pods,svc,ingress",

      # dvwa
      "kubectl apply -f /home/gage/manifests/dvwa/namespace-dvwa.yaml",
      "kubectl apply -f /home/gage/manifests/dvwa/deployment-dvwa.yaml",
      "kubectl apply -f /home/gage/manifests/dvwa/service-dvwa.yaml",
      "kubectl apply -f /home/gage/manifests/dvwa/ingress-dvwa.yaml",
      "kubectl apply -f /home/gage/manifests/dvwa/hpa-dvwa.yaml",
      "kubectl -n dvwa get pods,svc,ingress",

      # dvga
      "kubectl apply -f /home/gage/manifests/juice-shop/namespace-juice-shop.yaml",
      "kubectl apply -f /home/gage/manifests/juice-shop/deployment-juice-shop.yaml",
      "kubectl apply -f /home/gage/manifests/juice-shop/service-juice-shop.yaml",
      "kubectl apply -f /home/gage/manifests/juice-shop/ingress-juice-shop.yaml",
      "kubectl apply -f /home/gage/manifests/juice-shop/hpa-juice-shop.yaml",
      "kubectl -n juice-shop get pods,svc,ingress",


      # KIC and NGF namespace setup
      "kubectl create namespace nginx-ingress --dry-run=client -o yaml | kubectl apply -f -",
      "kubectl create namespace nginx-gateway --dry-run=client -o yaml | kubectl apply -f -",


      # KIC setup
      # Image pull secret (JWT authenticates you to the F5 private registry)
      "kubectl create secret docker-registry regcred --docker-server=private-registry.nginx.com --docker-username=$(cat /home/gage/secrets/nginx-repo.jwt) --docker-password=none -n nginx-ingress",

      # License secret
      "kubectl create secret generic nplus-license --from-file=license.jwt=/home/gage/secrets/nginx-repo.jwt -n nginx-ingress",

      # Install
      "helm install nic oci://ghcr.io/nginx/charts/nginx-ingress --namespace nginx-ingress --set controller.ingressClass.name=nginx-plus --set controller.nginxplus=true --set controller.image.repository=private-registry.nginx.com/nginx-ic/nginx-plus-ingress --set controller.image.tag=5.5.4 --set controller.serviceAccount.imagePullSecretName=regcred --set controller.mgmt.licenseTokenSecretName=nplus-license",

      # NGF setup
      "kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml",

      # Image pull secret (JWT authenticates you to the F5 private registry)
      "kubectl create secret docker-registry nginx-plus-registry-secret --docker-server=private-registry.nginx.com --docker-username=$(cat /home/gage/secrets/nginx-repo.jwt) --docker-password=none -n nginx-gateway",

      # License secret
      "kubectl create secret generic nplus-license --from-file=license.jwt=/home/gage/secrets/nginx-repo.jwt -n nginx-gateway",

      # Install
      "helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --namespace nginx-gateway --set nginx.plus=true --set nginx.image.repository=private-registry.nginx.com/nginx-gateway-fabric/nginx-plus --set nginx.imagePullSecret=nginx-plus-registry-secret"
    ]
  }
}
