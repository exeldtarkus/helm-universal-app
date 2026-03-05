readmefile tolong buatkan berdasarkan data di bawah

strukture folder

k8s-helm-chart-app/
├── Chart.yaml             # Metadata dari chart ini
├── values.yaml            # File pusat konfigurasi (Ini yang akan sering kamu ubah)
└── templates/             # Folder berisi file template YAML K8s
    ├── _helpers.tpl       # Kumpulan fungsi bantuan untuk penamaan dinamis
    ├── deployment.yaml    # Template K8s Deployment (mengatur Pod & Replicas)
    └── service.yaml       # Template K8s Service (mengatur Port & Network)
    ---- ingress.yaml di dalam template dan berikan penjelasan



Langkah 1: Buat Kunci Akses (Secret) untuk Nexus
Kubernetes butuh izin untuk menarik image dari port 8802 Nexus kamu. Jalankan perintah ini (ubah SANGAT PENTING di bagian username dan password dengan kredensial Nexus kamu):

# Hapus yang lama dulu
kubectl delete secret nexus-docker-secret

# Buat yang baru dengan IP dan Port yang sesuai setting Nexus terbaru
kubectl create secret docker-registry nexus-docker-secret \
  --docker-server=localhost:8802 \
  --docker-username=admin \
  --docker-password=bcalife.1234

# keterangan (10.3.1.67 repository nexus):(8802 port yang di buka untuk nama repo simpan docker image = docker-image-development)


langkah 2: Deploy Aplikasi BIMA dengan Helm
Pastikan kamu berada di direktori yang sejajar dengan folder universal-app-chart yang tadi kita buat. Kita akan menggunakan perintah helm upgrade --install (lebih aman daripada helm install karena jika aplikasinya sudah ada, ia hanya akan melakukan update).

Jalankan perintah ini:

Bash
helm upgrade --install bima-app ./universal-app-chart \
  --set fullnameOverride=bima-app \
  --set image.repository=10.1.40.92:8802/bima-app \
  --set image.tag=latest \
  --set service.port=80 \
  --set service.targetPort=8080 \
  --set env.SPRING_PROFILES_ACTIVE=dev
Output yang diharapkan: Muncul ringkasan STATUS: deployed dari Helm.


ingress Controller
Ingress tidak akan jalan kalau "mesin" NGINX-nya belum ada di cluster. Jalankan ini sekali saja di cluster kamu:

Bash
# Untuk Docker Desktop (Windows)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml