# Application Helm Chart

Repositori ini berisi konfigurasi **Helm Chart** untuk men-deploy aplikasi ke dalam cluster **Kubernetes**. Struktur ini dirancang untuk mempermudah manajemen konfigurasi, deployment, dan routing jaringan menggunakan **Ingress**.

Helm Chart ini juga dapat **dipackage dan disimpan di Nexus Helm Repository** sehingga dapat digunakan sebagai **artifact deployment yang terpusat**.

---

# 📂 Struktur Direktori

Berikut adalah struktur folder dari Helm Chart ini beserta fungsinya:

```text
k8s-helm-chart-app/
├── Chart.yaml             # Metadata utama dari chart ini (nama, versi, deskripsi).
├── values.yaml            # File pusat konfigurasi default (parameter seperti image, port, environment variables).
└── templates/             # Folder berisi file template YAML Kubernetes yang akan dirender oleh Helm.
    ├── _helpers.tpl       # Template helper untuk standardisasi penamaan resource.
    ├── deployment.yaml    # Template Deployment Kubernetes (Pod, Replica, Image).
    ├── service.yaml       # Template Service Kubernetes (Port dan TargetPort).
    └── ingress.yaml       # Template Ingress untuk routing HTTP/HTTPS dari luar cluster.
```

---

# 🚀 Prasyarat (Prerequisites)

Pastikan cluster Kubernetes Anda sudah memiliki **Ingress Controller**.

Jika belum ada, install **NGINX Ingress Controller**:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

Ingress berfungsi sebagai **reverse proxy / API gateway** yang mengarahkan trafik dari luar cluster menuju Service aplikasi.

---

# 🛠️ Langkah-langkah Deployment

## 1️⃣ Membuat Secret untuk Akses Nexus Docker Registry

Agar Kubernetes dapat menarik Docker image dari **private Nexus repository**, diperlukan secret authentication.

### Hapus secret lama (jika ada)

```bash
kubectl delete secret nexus-docker-secret --ignore-not-found
```

### Buat secret baru

```bash
kubectl create secret docker-registry nexus-docker-secret \
  --docker-server=10.3.1.67:8802 \
  --docker-username=admin \
  --docker-password=admin
```

### Konfigurasi Nexus

| Parameter    | Nilai                    |
| ------------ | ------------------------ |
| Nexus Server | 10.3.1.67                |
| Port Docker  | 8802                     |
| Repository   | docker-image-development |

Secret ini akan digunakan pada **Deployment** melalui `imagePullSecrets`.

---

# 2️⃣ Deploy Aplikasi Menggunakan Helm

Jalankan perintah berikut dari direktori yang sejajar dengan folder chart:

```bash
helm upgrade --install app ./k8s-helm-chart-app \
  --set fullnameOverride=app \
  --set image.repository=10.1.40.92:8802/app \
  --set image.tag=latest \
  --set service.port=80 \
  --set service.targetPort=8080 \
  --set env.SPRING_PROFILES_ACTIVE=dev
```

### Penjelasan Parameter

| Parameter                  | Fungsi                            |
| -------------------------- | --------------------------------- |
| fullnameOverride           | Mengatur nama resource Kubernetes |
| image.repository           | Lokasi Docker image di Nexus      |
| image.tag                  | Versi image                       |
| service.port               | Port yang diexpose oleh service   |
| service.targetPort         | Port aplikasi di dalam container  |
| env.SPRING_PROFILES_ACTIVE | Environment variable Spring Boot  |

Jika berhasil, output Helm akan menampilkan:

```text
STATUS: deployed
```

---

# 📦 Publish Helm Chart ke Nexus Repository

Selain deploy langsung dari folder, Helm Chart juga dapat **dipackage dan disimpan di Nexus** agar menjadi **artifact deployment** seperti `.jar` atau `.war`.

---

# 3️⃣ Package Helm Chart

Masuk ke folder chart lalu jalankan:

```bash
helm package .
```

Output:

```text
Successfully packaged chart and saved it to:
universal-app-1.0.0.tgz
```

File `.tgz` inilah yang akan diupload ke Nexus.

---

# 4️⃣ Menambahkan Helm Repository Nexus

Tambahkan Nexus sebagai Helm repository:

```bash
helm repo add nexus-repo http://10.1.40.92:8082/repository/helm-internal/ \
  --username admin \
  --password admin
```

### Penjelasan

| Parameter         | Fungsi                           |
| ----------------- | -------------------------------- |
| helm repo add     | Menambahkan repository Helm baru |
| nexus-repo        | Nama alias repository            |
| URL               | URL Nexus Helm repository        |
| username/password | Credential akses repository      |

---

# 5️⃣ Upload Helm Chart ke Nexus

Helm tidak memiliki command built-in untuk upload chart ke Nexus, sehingga biasanya menggunakan **curl**.

```bash
curl -u admin:admin123 --upload-file universal-app-1.0.3.tgz http://10.1.40.213:31807/repository/helm-internal/universal-app-1.0.3.tgz
```
# Ganti bima-test-release dengan RELEASE_NAME kamu jika berbeda
helm upgrade bima-test-release bcalife-helm/universal-app --set service.type=NodePort --set service.nodePort=30001

### Penjelasan

| Parameter         | Fungsi                        |
| ----------------- | ----------------------------- |
| -u admin:password | Authentication Nexus          |
| -X PUT            | HTTP method upload file       |
| --upload-file     | File Helm Chart yang diupload |

---

### Alternatif Upload Helm Chart

Beberapa alternatif selain `curl`:

1️⃣ **Helm Push Plugin**

Install plugin:

```bash
helm plugin install https://github.com/chartmuseum/helm-push.git
```

Upload chart:

```bash
helm push universal-app-1.0.0.tgz nexus-repo
```

2️⃣ **Upload melalui UI Nexus**

Masuk ke:

```
Nexus → Repositories → helm-internal → Upload
```

Upload file `.tgz`.

---

# 6️⃣ Update Helm Repository

Setelah chart diupload ke Nexus, jalankan:

```bash
helm repo update
```

### Penjelasan

Perintah ini akan:

* Mengambil **index terbaru dari semua Helm repository**
* Memperbarui daftar chart yang tersedia
* Agar Helm mengetahui **chart baru yang baru saja diupload**

Tanpa `helm repo update`, Helm **tidak akan melihat chart terbaru** di repository.

---

# 7️⃣ Mencari Chart di Repository

Untuk melihat chart yang tersedia:

```bash
helm search repo nexus-repo/universal-app
```

### Penjelasan

| Parameter        | Fungsi                           |
| ---------------- | -------------------------------- |
| helm search repo | Mencari chart di repository Helm |
| nexus-repo       | Nama repo                        |
| universal-app    | Nama chart                       |

Contoh output:

```text
NAME                     CHART VERSION   APP VERSION   DESCRIPTION
nexus-repo/universal-app 1.0.0           1.0.0         Helm chart for universal app
```

---

# 8️⃣ Deploy Chart dari Nexus Repository

Setelah chart tersedia di Nexus, deploy bisa langsung dari repository:

```bash
helm install app nexus-repo/universal-app
```

atau upgrade:

```bash
helm upgrade app nexus-repo/universal-app
```

---

# 🔁 Workflow CI/CD yang Direkomendasikan

Workflow yang umum digunakan:

```text
Developer
   │
   │ build docker image
   ▼
Nexus Docker Registry
   │
   │ helm package
   ▼
Nexus Helm Repository
   │
   │ helm install / upgrade
   ▼
Kubernetes Cluster
```

Sehingga:

* **Docker Image** disimpan di Nexus
* **Helm Chart** disimpan di Nexus
* Kubernetes hanya melakukan **pull artifact**
