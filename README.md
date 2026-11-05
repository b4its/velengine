# Oryphem Laravel Engine

Setup container lengkap dan mandiri untuk ekosistem Laravel modern dengan **PHP 8.4 terbaru**, **Laravel Installer CLI**, **Node.js 22 LTS**, **Composer terbaru**, **MySQL 8.4**, **Redis**, dan **phpMyAdmin**.

Tiap kali Anda menjalankan perintah **`laravel new <nama_projek>`**, sistem akan **secara otomatis membuatkan setup Docker lengkap** (Nginx, PHP-FPM, MySQL 8.4, Redis, phpMyAdmin, Node/NPM) serta **Makefile mandiri** dengan seluruh perintah lengkap (`make up`, `down`, `shell-php`, `shell-db`, dll.) di dalam projek baru tersebut!

---

## ⚡ Fitur Utama

1. **Auto-Scaffold Docker & Makefile saat `laravel new`**:
   - Menghasilkan `docker-compose.yml`, `Dockerfile`, `docker/nginx/default.conf`, `docker/php/php.ini`, `docker/entrypoint.sh`, `.dockerignore`, dan `Makefile`.
   - Mengalokasikan port Docker bebas konflik secara otomatis.
   - Mengonfigurasi file `.env` dan `.env.example` langsung terhubung ke database `db` (MySQL) dan `redis`.
   - Mengonfigurasi `vite.config.js` untuk Hot Module Replacement (HMR) Docker.
2. **Mandiri & Fleksibel**:
   - Projek baru dapat dijalankan langsung secara mandiri (`cd <nama_projek> && make up`).
   - Atau disajikan melalui mesin utama ini (`PROJECT_DIR=<nama_projek> make up`).
3. **Makefile Lengkap & Berwarna**:
   - Menyediakan perintah developer terpadu: `make up`, `down`, `shell-php`, `shell-db`, `mysql`, `shell-nginx`, `shell-redis`, `dev`, `artisan`, `composer`, `npm`, `migrate`, `logs`, dan banyak lagi.

---

## 📌 Alokasi Port Mesin Utama ({Port Standar} + 99)

| Layanan | Port Standar | Rumus | Port Host Aktif | Akses URL / Host |
| :--- | :---: | :---: | :---: | :--- |
| **Web Application (Nginx / App)** | `8000` | `8000 + 99` | **`8099`** | [http://localhost:8099](http://localhost:8099) |
| **Vite Dev Server (HMR)** | `5173` | `5173 + 99` | **`5272`** | [http://localhost:5272](http://localhost:5272) |
| **MySQL Database** | `3306` | `3306 + 99` | **`3405`** | `127.0.0.1:3405` |
| **phpMyAdmin (GUI DB)** | `8080` | `8080 + 99` | **`8179`** | [http://localhost:8179](http://localhost:8179) |
| **Redis Cache & Queue** | `6379` | `6379 + 99` | **`6478`** | `127.0.0.1:6478` |

*(Projek baru yang digenerate otomatis menggunakan port standar yang tersedia seperti 8000, 5173, 3306, 8080, 6379 atau port berikutnya jika sudah terpakai).*

---

## 🚀 Cara Membuat Projek Laravel Baru

Tersedia beberapa cara praktis sesuai preferensi Anda. Setiap cara akan **otomatis menghasilkan setup Docker & Makefile**:

### Cara 1: Menggunakan Script Wrapper `./laravel` (Rekomendasi)
Di terminal host, jalankan perintah:
```bash
./laravel new nama_projek
```
> **Tip:** Anda bisa membuat alias di `~/.bashrc` atau `~/.zshrc`:
> ```bash
> alias laravel="$PWD/laravel"
> ```
> Setelah itu Anda cukup menjalankan `laravel new nama_projek` dari mana saja.

### Cara 2: Menggunakan Makefile
```bash
# Menentukan nama langsung (otomatis disimpan di folder projects/):
make new PROJECT=nama_projek

# Atau inisialisasi langsung di folder root saat ini:
make new-here
```

### Cara 3: Melalui Shell Container
```bash
make shell-php
laravel new nama_projek
```

Setelah proses selesai, projek baru akan langsung tersimpan di dalam folder `projects/<nama_projek>` lengkap dengan `docker-compose.yml`, `Dockerfile`, folder `docker/`, dan `Makefile`. Anda cukup berpindah ke direktori tersebut:
```bash
cd projects/nama_projek
make up
make info
```

---

## 📋 Daftar Perintah Makefile Lengkap

Jalankan `make` atau `make help` untuk melihat ringkasan perintah interaktif berwarna. Tersedia di mesin utama maupun di setiap projek yang digenerate:

### 1. Manajemen Siklus Hidup Container
- `make up` : Nyalakan seluruh stack (Nginx, App PHP 8.4, MySQL, Redis, phpMyAdmin) di background.
- `make down` : Matikan seluruh container (volume data MySQL & Redis tetap aman).
- `make down-v` : Matikan container dan **hapus semua volume** data (reset database dari nol).
- `make restart` : Restart seluruh service container.
- `make build` : Build ulang image container Dockerfile.
- `make rebuild` : Build ulang image dari awal tanpa cache (`--no-cache`).

### 2. Status & Informasi Sistem
- `make status` / `make ps` : Tampilkan tabel status container, status health, dan port mapping.
- `make info` : Tampilkan ringkasan URL, port, kredensial database, serta rincian versi (PHP, Laravel, Composer, Node, NPM).

### 3. Shell & Akses Terminal
- `make shell-php` / `make shell` : Masuk ke terminal bash container PHP sebagai developer non-root (UID 1000).
- `make shell-php-root` / `make root` : Masuk ke terminal bash container PHP sebagai `root`.
- `make shell-db` : Masuk ke terminal bash di dalam container MySQL Database.
- `make mysql` / `make db-cli` : Masuk langsung ke prompt interaktif MySQL CLI (`mysql -u... -p...`).
- `make shell-nginx` : Masuk ke terminal shell container Nginx.
- `make shell-redis` / `make redis-cli` : Masuk langsung ke interactive redis-cli.

### 4. Developer Tools, Artisan, Composer & NPM
- `make artisan cmd="..."` : Jalankan perintah `php artisan` (contoh: `make artisan cmd="migrate"`).
- `make art cmd="..."` : Alias ringkas untuk `make artisan`.
- `make composer cmd="..."` : Jalankan perintah `composer` (contoh: `make composer cmd="require filament/filament"`).
- `make npm cmd="..."` : Jalankan perintah `npm` (contoh: `make npm cmd="install"`).
- `make dev` : Jalankan Vite development server (HMR) yang terekspos ke host.
- `make build-assets` : Build frontend assets untuk production (`npm run build`).
- `make tinker` : Buka sesi interaktif Laravel Tinker.
- `make test` : Jalankan unit test / Pest / PHPUnit.
- `make migrate` : Jalankan migrasi database (`php artisan migrate`).
- `make migrate-fresh` : Jalankan migrasi ulang dari awal beserta seeder (`php artisan migrate:fresh --seed`).
- `make migrate-rollback` : Rollback batch migrasi terakhir.
- `make seed` : Jalankan database seeder (`php artisan db:seed`).
- `make key` : Generate application key baru (`php artisan key:generate`).
- `make storage-link` : Buat symbolic link public storage (`php artisan storage:link`).
- `make clear` : Bersihkan seluruh cache aplikasi Laravel (`optimize:clear`).
- `make optimize` : Cache konfigurasi, route, dan view untuk performa maksimal.
- `make perm` : Perbaiki permission folder `storage/` dan `bootstrap/cache/` (chmod 775, chown 1000:1000).

### 5. Logging & Pemantauan
- `make logs` : Pantau log realtime seluruh container (Ctrl+C untuk keluar).
- `make logs-php` / `make logs-app` : Pantau log container PHP application.
- `make logs-nginx` : Pantau log web server Nginx.
- `make logs-db` : Pantau log database MySQL.
- `make logs-redis` : Pantau log container Redis.
- `make logs-pma` : Pantau log container phpMyAdmin.

---

## 🗄️ Kredensial Database Mesin Utama

- **Host (dari Host OS)**: `127.0.0.1`
- **Host (dari dalam Container)**: `db`
- **Port Host**: `3405`
- **Database**: `machine`
- **Username**: `machine`
- **Password**: `secret`
- **Root Password**: `root`
