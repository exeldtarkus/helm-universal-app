#!/bin/bash
# Matikan set -e agar script tidak langsung terhenti jika perintah helm gagal
# set -e 

echo "🚀 Memulai proses setup cluster..."

# ==========================================
# 1. Create Namespaces
# ==========================================
echo "📦 1. [create-namespace] - Menyiapkan namespace..."
kubectl create namespace cicd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace cicd-api-deploy --dry-run=client -o yaml | kubectl apply -f -

# ==========================================
# 2. Install NGINX Ingress Controller
# ==========================================
echo "🌐 2. [install-nginx] - Mengecek & Install NGINX Ingress Controller dari OCI Registry..."

helm upgrade --install ingress-nginx oci://ghcr.io/nginx/charts/nginx-ingress \
  --version 2.4.4 \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --wait || echo "⚠️ [install-nginx] - Gagal install Ingress. Melanjutkan ke tahap berikutnya..."

# ==========================================
# 3. Install Local Registry
# ==========================================
echo "🐳 3. [install-registry] - Menyiapkan Local K8s Registry..."
kubectl apply -f server/k8s/deployment/registry-local.yaml -n cicd-api-deploy

echo "⏳ Menunggu Local Registry siap..."
kubectl rollout status deployment/local-registry -n cicd-api-deploy --timeout=60s || echo "⚠️ Timeout menunggu registry, tapi kita coba lanjut..."

# ==========================================
# 4. Build & Push via Kaniko
# ==========================================
echo "🏗️ 4. [kaniko-run] - Menjalankan Kaniko Job..."

kubectl delete job build-deploy-api -n cicd-api-deploy --ignore-not-found
kubectl apply -f server/k8s/job/kaniko-build-deploy-api.yaml -n cicd-api-deploy

echo "⏳ [kaniko-run] - Menunggu Kaniko job selesai (max 5 menit)..."
attempt=0
while [ $attempt -lt 60 ]; do
    status=$(kubectl get job build-deploy-api -n cicd-api-deploy -o jsonpath='{.status.succeeded}' 2>/dev/null)
    
    if [ "$status" == "1" ]; then
        echo -e "\n✅ [kaniko-run] - Kaniko build sukses!"
        break
    fi
    
    echo -n "."
    sleep 5
    attempt=$((attempt+1))
done

if [ "$status" != "1" ]; then
    echo -e "\n❌ [kaniko-run] - Kaniko build timeout atau gagal. Silakan cek log: kubectl logs job/build-deploy-api -n cicd-api-deploy"
    exit 1
fi

# ==========================================
# 5. Deploy Server API
# ==========================================
echo -e "\n🚀 5. [run api] - Menjalankan Deploy API Server..."
kubectl apply -f server/k8s/deployment/api-deployment.yaml -n cicd-api-deploy

echo "🎉 [run api] - Selesai! Cek status pod dengan: kubectl get pods -n cicd-api-deploy"