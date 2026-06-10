## 🔧 Development Notes

### Mendapatkan SHA-1 Android Debug

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android
```

---

### Generate Launcher Icon

Digunakan untuk menghasilkan icon aplikasi Android dan iOS berdasarkan konfigurasi pada `pubspec.yaml`.

```bash
flutter pub run flutter_launcher_icons
```

---

### Membuat dan Menyiapkan REST API

Install dependency yang digunakan oleh REST API:

```bash
npm install express firebase-admin body-parser cors dotenv nodemon
```

---

# 🐾 Paws & Care

Paws & Care adalah aplikasi mobile berbasis Flutter yang dirancang untuk membantu masyarakat dalam melaporkan, memantau, dan menangani kasus hewan yang hilang, terlantar, atau membutuhkan bantuan. Aplikasi ini menghubungkan pelapor dengan relawan melalui sistem pelaporan, notifikasi real-time, dan pelacakan lokasi berbasis GPS.

---

## ✨ Fitur Utama

### 🔐 Autentikasi

- Registrasi akun menggunakan Email & Password
- Login menggunakan Email & Password
- Login menggunakan Google Account
- Auto Login menggunakan Firebase Authentication
- Logout akun

### 👤 Manajemen Profil

- Edit profil pengguna
- Upload foto profil
- Hapus foto profil
- Ubah password dengan validasi keamanan
- Dark Mode
- Penyimpanan preferensi menggunakan Shared Preferences

### 📢 Laporan Hewan

- Membuat laporan baru
- Upload foto hewan
- Lokasi otomatis menggunakan GPS
- Lokasi manual menggunakan alamat
- Edit laporan
- Hapus laporan
- Update lokasi GPS
- Tambah detail lokasi

### 🤝 Sistem Relawan

- Menjadi relawan pada laporan
- Maksimal 3 relawan per laporan
- Membatalkan bantuan
- Mengunggah bukti penyelesaian

### ✅ Konfirmasi Penyelesaian

- Relawan mengirim bukti penyelesaian
- Pemilik laporan melakukan verifikasi
- Menyetujui atau menolak penyelesaian
- Status laporan diperbarui sesuai hasil verifikasi

### ❤️ Favorit

- Menambahkan laporan ke favorit
- Menghapus laporan dari favorit
- Melihat daftar laporan favorit

### 💬 Komentar

- Menambahkan komentar
- Melihat komentar secara real-time
- Notifikasi komentar pada laporan terkait

### 🔔 Notifikasi

- Firebase Cloud Messaging (FCM)
- Local Notification
- Filter kategori notifikasi
- Filter jenis hewan
- Pengaturan notifikasi personal

### 🗺️ Peta Laporan

- Menampilkan laporan pada Google Maps
- Marker berdasarkan lokasi GPS
- Navigasi ke Google Maps
- Filter laporan berdasarkan kategori dan jenis hewan

---

## 🛠️ Teknologi yang Digunakan

### Framework

- Flutter
- Dart

### Backend & Cloud

- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Messaging (FCM)

### Integrasi Pihak Ketiga

- Google Sign-In
- Google Maps Flutter
- Geolocator
- Geocoding

### Penyimpanan Lokal

- Shared Preferences

### Media

- Image Picker
- Image Cropper

### Notifikasi

- Flutter Local Notifications

---

## 📂 Struktur Project

```text
lib/
├── models/
├── screens/
├── services/
├── widgets/
├── utils/
├── assets/
├── firebase_options.dart
└── main.dart
```

### Folder Utama

| Folder   | Fungsi                                 |
| -------- | -------------------------------------- |
| models   | Struktur data aplikasi                 |
| screens  | Halaman utama aplikasi                 |
| services | Logika bisnis dan integrasi Firebase   |
| widgets  | Komponen UI yang dapat digunakan ulang |
| utils    | Helper dan utility                     |
| assets   | Gambar dan aset aplikasi               |

---

## 🔥 Firebase Services

### Authentication

Digunakan untuk:

- Login Email
- Registrasi
- Login Google
- Manajemen sesi pengguna

### Cloud Firestore

Digunakan untuk:

- Data pengguna
- Data laporan
- Data komentar
- Data notifikasi

### Firebase Cloud Messaging

Digunakan untuk:

- Notifikasi laporan baru
- Notifikasi komentar
- Notifikasi relawan
- Notifikasi perubahan status laporan

---

## 🗃️ Struktur Database

### users

Menyimpan informasi pengguna.

Contoh field:

```json
{
  "uid": "...",
  "username": "...",
  "email": "...",
  "role": "Pengguna",
  "fcmToken": "...",
  "notificationPrefs": {}
}
```

### posts

Menyimpan data laporan hewan.

Contoh field:

```json
{
  "title": "...",
  "description": "...",
  "categories": [],
  "latitude": 0.0,
  "longitude": 0.0,
  "status": "Menunggu Relawan"
}
```

### comments

Menyimpan komentar pada laporan.

```json
{
  "postId": "...",
  "userId": "...",
  "comment": "...",
  "createdAt": "..."
}
```

---

## 🔄 Alur Sistem

### Membuat Laporan

```text
User
 ↓
Input Data Laporan
 ↓
Upload Foto
 ↓
Pilih Lokasi
 ↓
Firestore
 ↓
Notifikasi Pengguna Lain
 ↓
Laporan Muncul di Home
```

### Menjadi Relawan

```text
User
 ↓
Klik Saya Bantu
 ↓
Firestore Update
 ↓
Status Menjadi Sedang Ditangani
 ↓
Pemilik Mendapat Notifikasi
```

### Penyelesaian Laporan

```text
Relawan
 ↓
Upload Bukti
 ↓
Menunggu Konfirmasi
 ↓
Pemilik Menyetujui
 ↓
Status Berhasil Ditangani
```

---

## 🚀 Instalasi

### Clone Repository

```bash
git clone https://github.com/username/paws-care.git
```

### Masuk ke Folder Project

```bash
cd paws-care
```

### Install Dependency

```bash
flutter pub get
```

### Jalankan Aplikasi

```bash
flutter run
```

---

## ⚙️ Konfigurasi Firebase

Project ini memerlukan konfigurasi Firebase sebelum dijalankan:

1. Buat project Firebase.
2. Tambahkan aplikasi Android.
3. Download file:

```text
google-services.json
```

4. Letakkan pada:

```text
android/app/google-services.json
```

5. Aktifkan:

- Authentication
- Firestore Database
- Cloud Messaging

6. Tambahkan SHA-1 dan SHA-256 untuk Google Sign-In.

---

## 📦 Dependency Utama

- firebase_core
- firebase_auth
- cloud_firestore
- firebase_messaging
- google_sign_in
- flutter_local_notifications
- google_maps_flutter
- geolocator
- geocoding
- image_picker
- image_cropper
- shared_preferences
- http
- intl

---

## 🔒 Keamanan

- Firebase Authentication
- Validasi password
- Validasi input pengguna
- Otorisasi berdasarkan role
- Pembatasan akses fitur tertentu

---

## 📌 Catatan Pengembangan

Beberapa area yang masih dapat ditingkatkan:

- Migrasi penyimpanan gambar dari Base64 ke Firebase Storage
- Optimasi performa marker Google Maps
- Caching gambar menggunakan CachedNetworkImage
- Dashboard admin yang lebih lengkap
- Statistik laporan dan aktivitas pengguna

---

## 👨‍💻 Developer

Project ini dikembangkan sebagai aplikasi pelaporan dan penanganan hewan berbasis Flutter dengan integrasi Firebase, Google Maps, dan Firebase Cloud Messaging.

---

## 📄 License

Project ini dibuat untuk kebutuhan pembelajaran, pengembangan aplikasi mobile, dan tugas akademik.
