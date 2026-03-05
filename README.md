# Application Helm Chart

Repositori ini berisi konfigurasi Helm Chart untuk men-deploy aplikasi ke dalam cluster Kubernetes. Struktur ini dirancang untuk mempermudah manajemen konfigurasi, deployment, dan routing jaringan menggunakan Ingress.

## 📂 Struktur Direktori

Berikut adalah struktur folder dari Helm Chart ini beserta fungsinya:

```text
k8s-helm-chart-app/
├── Chart.yaml             # Metadata utama dari chart ini (nama, versi, deskripsi).
├── values.yaml            # File pusat konfigurasi default (parameter yang sering diubah seperti image, port, environment variables).
└── templates/             # Folder berisi file template YAML Kubernetes yang akan dirender oleh Helm.
    ├── _helpers.tpl       # Kumpulan fungsi bantuan (template functions) untuk standardisasi penamaan dinamis di seluruh file YAML.
    ├── deployment.yaml    # Template K8s Deployment: Mengatur spesifikasi Pod, Replicas, dan container image yang digunakan.
    ├── service.yaml       # Template K8s Service: Mengatur eksposur jaringan internal cluster (Port & TargetPort).
    └── ingress.yaml       # Template K8s Ingress: Mengatur routing trafik HTTP/HTTPS dari luar cluster masuk ke Service aplikasi. Berfungsi sebagai API Gateway atau reverse proxy.

```

---

## 🚀 Prasyarat (Prerequisites)

Sebelum melakukan deployment, pastikan cluster Kubernetes Anda sudah memiliki **Ingress Controller**. Ingress tidak akan berjalan jika mesin NGINX-nya belum terinstal di dalam cluster.

Jalankan perintah berikut (cukup sekali saja di cluster Anda) untuk menginstal NGINX Ingress Controller di lingkungan **Docker Desktop (Windows)**:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

```

---

## 🛠️ Langkah-langkah Deployment

### Langkah 1: Buat Kunci Akses (Secret) untuk Nexus

Kubernetes membutuhkan izin otentikasi (Secret) untuk menarik (*pull*) Docker image dari private repository Nexus Anda.

1. Hapus secret lama jika sudah ada untuk menghindari konflik:
```bash
kubectl delete secret nexus-docker-secret --ignore-not-found

```


2. Buat secret baru dengan kredensial Nexus Anda:
```bash
kubectl create secret docker-registry nexus-docker-secret \
  --docker-server=10.3.1.67:8802 \
  --docker-username=admin \
  --docker-password=bcalife.1234

```


> **Catatan Konfigurasi Nexus:**


> * **IP Repository Nexus:** `10.3.1.67`
> * **Port:** `8802` (Port yang dibuka khusus untuk menyimpan Docker image).
> * **Nama Repository:** `docker-image-development`
> *(Pastikan untuk menyesuaikan `docker-server` dengan IP dan Port yang aktif jika terdapat perubahan environment).*
> 
> 



### Langkah 2: Deploy Aplikasi dengan Helm

Pastikan terminal Anda berada di direktori yang sejajar dengan folder `k8s-helm-chart-app`. Gunakan perintah `helm upgrade --install` agar Helm otomatis melakukan instalasi baru atau mengupdate jika aplikasi sudah pernah di-deploy sebelumnya.

Jalankan perintah berikut:

```bash
helm upgrade --install-app ./k8s-helm-chart-app \
  --set fullnameOverride-app \
  --set image.repository=10.1.40.92:8802-app \
  --set image.tag=latest \
  --set service.port=80 \
  --set service.targetPort=8080 \
  --set env.SPRING_PROFILES_ACTIVE=dev

```

**Penjelasan Parameter (Overrides):**

* `fullnameOverride-app`: Memaksa nama resource K8s menjadi -app` tanpa embel-embel nama release.
* `image.repository`: Lokasi image Docker aplikasi di registry Nexus.
* `image.tag`: Versi image yang akan ditarik (`latest`).
* `service.port` & `targetPort`: Mapping port Service (`80`) ke port aplikasi di dalam container (`8080`).
* `env.SPRING_PROFILES_ACTIVE=dev`: Mengatur environment variable Spring Boot agar berjalan di profil *development*.

**Output yang diharapkan:**
Anda akan melihat ringkasan dari Helm di terminal dengan keterangan `STATUS: deployed`, menandakan aplikasi telah berhasil dijalankan.

---

Apakah Anda ingin saya tambahkan contoh isi dari file `ingress.yaml` dan `values.yaml` untuk melengkapi setup ini?