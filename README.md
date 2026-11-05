# Vel Engine - Laravel Engine

[![PHP Version](https://img.shields.io/badge/PHP-8.4-777BB4?style=flat&logo=php&logoColor=white)](https://www.php.net/)
[![Laravel](https://img.shields.io/badge/Laravel-12.x-FF2D20?style=flat&logo=laravel&logoColor=white)](https://laravel.com/)
[![Docker](https://img.shields.io/badge/Docker-Enabled-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![Node.js](https://img.shields.io/badge/Node.js-22_LTS-5FA04E?style=flat&logo=node.js&logoColor=white)](https://nodejs.org/)
[![MySQL](https://img.shields.io/badge/MySQL-8.4-4479A1?style=flat&logo=mysql&logoColor=white)](https://www.mysql.com/)
[![Redis](https://img.shields.io/badge/Redis-7_Alpine-DC382D?style=flat&logo=redis&logoColor=white)](https://redis.io/)

**Vel Engine** adalah platform runtime, generator, dan development environment terintegrasi berbasis Docker untuk ekosistem modern Laravel. Dilengkapi dengan **PHP 8.4-FPM**, **Laravel Installer CLI**, **Composer terbaru**, **Node.js 22 LTS**, **MySQL 8.4**, **Redis**, dan **phpMyAdmin**.

Keunggulan utama Vel Engine: setiap kali Anda membuat projek baru menggunakan `laravel new` atau `make new`, engine akan **secara otomatis membuatkan setup Docker mandiri** (Nginx, PHP-FPM, MySQL, PMA, Redis, Vite) beserta **Makefile lengkap** di dalam subfolder **`projects/<nama_projek>`**.

---

## ⚡ Fitur Utama

1. **Auto-Scaffolding Docker & Makefile Otomatis**:
   - Menghasilkan arsitektur container lengkap: `docker-compose.yml`, `Dockerfile`, `docker/nginx/default.conf`, `docker/php/php.ini`, `docker/entrypoint.sh`, `.dockerignore`, dan `Makefile`.
   - Menata seluruh projek baru ke dalam folder terisolasi: **`projects/<nama_projek>`**.
   - Mengonfigurasi file `.env` dan `.env.example` seketika untuk langsung terhubung ke service database MySQL (`db`) dan Redis (`redis`).
   - Memodifikasi `vite.config.js` secara otomatis agar Hot Module Replacement (HMR) bind ke `0.0.0.0` dan lancar diakses dari browser host.

2. **Alokasi Port Acak / Random (Bebas Port Inti Sistem)**:
   - Port setiap service (`APP_PORT`, `VITE_PORT`, `DB_PORT`, `PMA_PORT`, `REDIS_PORT`) dialokasikan secara **acak/random** pada rentang aman **`15000 - 49999`**.
   - **Bebas Port Inti Sistem**: Sistem secara ketat melarang penggunaan port sistem/inti (`< 1024`, `3306`, `5432`, `6379`, `8000`, `8080`, `5173`, `8099`, dll.).
   - Setiap port yang dipilih diuji secara realtime melalui socket binding pada `0.0.0.0` dan `127.0.0.1` sehingga dijamin 100% bebas bentrok antar-projek.

3. **Deteksi Perangkat & Otomatisasi Firewall Linux**:
   - Sistem secara otomatis memeriksa OS / perangkat pengguna (`uname -s`).
   - **Jika Linux**: Mendeteksi firewall aktif (**UFW**, **firewalld**, atau **iptables**) dan otomatis mengonfigurasi aturan firewall untuk membuka port yang dialokasikan agar tidak bentrok atau terblokir.
   - **Jika Non-Linux (macOS / Windows)**: Konfigurasi firewall dilewati secara otomatis tanpa gangguan (*gracefully skipped*).

4. **Dua Mode Eksekusi Fleksibel**:
   - **Mode Mandiri (Stand-Alone)**: Masuk ke folder projek (`cd projects/<nama_projek>`) lalu jalankan `make up`. Projek berjalan sepenuhnya di container dan network miliknya sendiri.
   - **Mode Terpusat (Vel Engine Core)**: Tetapkan `PROJECT_DIR=projects/<nama_projek>` di file `.env` utama, lalu disajikan langsung melalui Nginx Vel Engine di port `8099`.

5. **Command Center Makefile Lengkap & Interaktif**:
   - Tersedia puluhan perintah developer berwarna untuk lifecycle container, akses shell PHP & MySQL, migrate, seed, tinker, artisan, composer, npm, hingga perbaikan hak akses permission folder.

---

## 📌 Alokasi Port Vel Engine Utama ({Port Standar} + 99)

Layanan mesin utama dikonfigurasi dengan rumus alokasi **`Port Standar + 99`** untuk menjamin tidak bertabrakan dengan service bawaan di komputer host:

| Layanan | Port Standar | Rumus Alokasi | Port Host Aktif | Akses URL / Endpoint |
| :--- | :---: | :---: | :---: | :--- |
| **Web Application (Nginx)** | `8000` | `8000 + 99` | **`8099`** | [http://localhost:8099](http://localhost:8099) |
| **Vite Dev Server (HMR)** | `5173` | `5173 + 99` | **`5272`** | [http://localhost:5272](http://localhost:5272) |
| **MySQL Database** | `3306` | `3306 + 99` | **`3405`** | `127.0.0.1:3405` |
| **phpMyAdmin (GUI DB)** | `8080` | `8080 + 99` | **`8179`** | [http://localhost:8179](http://localhost:8179) |
| **Redis Cache & Queue** | `6379` | `6379 + 99` | **`6478`** | `127.0.0.1:6478` |

> [!NOTE]
> Setiap projek baru yang dibuat di dalam folder `projects/` akan mendapatkan alokasi port **acak / random** (rentang `15000 - 49999`) dan dilarang memakai port inti sistem. Sistem juga otomatis mendeteksi firewall Linux (`UFW` / `firewalld`) dan mengizinkan port tersebut agar siap diakses.

---

## 📂 Struktur Direktori

```text
machine/
├── docker/
│   ├── nginx/templates/default.conf.template  # Template Nginx reverse proxy engine
│   ├── php/php.ini                            # Konfigurasi PHP runtime
│   ├── entrypoint.sh                          # Docker runtime entrypoint
│   ├── firewall-helper.sh                     # Deteksi OS & pembuka firewall Linux
│   ├── laravel-wrapper.sh                     # Interceptor installer di container
│   └── scaffold-project.sh                    # Engine auto-scaffold Docker & Makefile
├── projects/                                  # Tempat seluruh hasil projek disimpan
│   └── .gitkeep
├── templates/
│   └── project/                               # Blueprint Docker & Makefile untuk projek baru
│       ├── docker/
│       │   ├── nginx/default.conf
│       │   ├── php/php.ini
│       │   └── entrypoint.sh
│       ├── .dockerignore
│       ├── docker-compose.yml.stub
│       ├── Dockerfile.stub
│       └── Makefile.stub
├── docker-compose.yml                         # Stack utama Vel Engine
├── Dockerfile                                 # Image PHP 8.4 + Node 22 + Composer
├── Makefile                                   # Command Center Vel Engine
├── laravel                                    # CLI wrapper installer untuk host
├── .env                                       # Environment konfigurasi Vel Engine
├── .env.example
└── README.md
```

---

## 🚀 Cara Membuat Projek Laravel Baru

Vel Engine menyediakan berbagai metode praktis. Apapun metode yang dipilih, **setup Docker & Makefile akan dibuatkan secara otomatis**:

### Cara 1: Menggunakan Makefile (Rekomendasi)
```bash
# Buat projek baru (otomatis tersimpan di folder projects/):
make new PROJECT=toko-online

# Dengan opsi tambahan installer (contoh: starter kit atau pest):
make new PROJECT=portal-berita ARGS="--pest"
```

### Cara 2: Menggunakan Wrapper Script Host (`./laravel`)
```bash
./laravel new nama_projek
```
> [!TIP]
> Anda dapat menambahkan alias di `~/.bashrc` atau `~/.zshrc`:
> ```bash
> alias laravel="$PWD/laravel"
> ```
> Setelah itu, Anda dapat memanggil `laravel new nama_projek` langsung dari mana saja.

### Cara 3: Dari Dalam Shell Container
```bash
make shell-php
laravel new nama_projek
```

### Cara 4: Inisialisasi di Root Saat Ini
Jika Anda ingin meletakkan kode aplikasi langsung di folder root `machine`:
```bash
make new-here
```

---

## 💻 Menjalankan Projek Baru

Setelah proses pembuatan selesai, pindah ke folder projek di dalam `projects/`:

```bash
cd projects/toko-online

# 1. Nyalakan seluruh stack container (Nginx, PHP, MySQL, Redis, phpMyAdmin)
make up

# 2. Cek alokasi port dan URL akses
make info

# 3. Jalankan Vite development server (HMR)
make dev
```

---

## 📋 Daftar Perintah Makefile Lengkap

Jalankan `make` atau `make help` untuk melihat ringkasan perintah interaktif berwarna. Perintah berikut berlaku pada Vel Engine maupun pada setiap projek yang digenerate di folder `projects/`:

### 1. Siklus Hidup Container
- `make up` : Nyalakan seluruh stack (Nginx, App PHP 8.4, MySQL, Redis, phpMyAdmin) di background.
- `make down` : Matikan seluruh container (volume data MySQL & Redis tetap aman).
- `make down-v` : Matikan container dan **hapus semua volume** data (reset total database).
- `make restart` : Restart seluruh service container.
- `make build` : Build ulang image container Dockerfile.
- `make rebuild` : Build ulang image container dari awal tanpa cache (`--no-cache`).

### 2. Status & Informasi
- `make status` / `make ps` : Tampilkan tabel status container, status healthcheck, dan port mapping.
- `make info` : Tampilkan ringkasan URL, alokasi port aktif, kredensial database, serta rincian versi (PHP, Laravel, Composer, Node, NPM).

### 3. Akses Shell & Terminal
- `make shell-php` / `make shell` : Buka interactive bash shell di container PHP sebagai developer non-root (UID 1000).
- `make shell-php-root` / `make root` : Buka interactive bash shell di container PHP sebagai `root`.
- `make shell-db` : Buka interactive bash terminal di container MySQL Database.
- `make mysql` / `make db-cli` : Masuk langsung ke interactive prompt MySQL CLI (`mysql -u... -p...`).
- `make shell-nginx` : Buka terminal shell di container Nginx.
- `make shell-redis` / `make redis-cli` : Buka interactive session redis-cli.

### 4. Developer Tools, Artisan, Composer & NPM
- `make artisan cmd="..."` : Jalankan perintah `php artisan` (contoh: `make artisan cmd="migrate"`).
- `make art cmd="..."` : Alias ringkas untuk `make artisan`.
- `make composer cmd="..."` : Jalankan perintah `composer` (contoh: `make composer cmd="require filament/filament"`).
- `make npm cmd="..."` : Jalankan perintah `npm` (contoh: `make npm cmd="install"`).
- `make dev` : Jalankan Vite development server (HMR) yang terhubung ke port host.
- `make build-assets` : Build frontend assets untuk production (`npm run build`).
- `make tinker` : Buka sesi interaktif Laravel Tinker.
- `make test` : Jalankan unit test aplikasi (Pest / PHPUnit).
- `make migrate` : Jalankan migrasi database (`php artisan migrate`).
- `make migrate-fresh` : Reset database dan jalankan ulang semua migrasi beserta seeder (`migrate:fresh --seed`).
- `make migrate-rollback` : Rollback batch migrasi terakhir.
- `make seed` : Jalankan database seeder (`php artisan db:seed`).
- `make key` : Generate application key baru (`php artisan key:generate`).
- `make storage-link` : Buat symbolic link public storage (`php artisan storage:link`).
- `make clear` : Bersihkan seluruh cache aplikasi Laravel (`optimize:clear`).
- `make optimize` : Cache konfigurasi, route, dan view untuk performa maksimal.
- `make perm` : Perbaiki hak akses direktori `storage/` dan `bootstrap/cache/` (chmod 775, chown 1000:1000).

### 5. Logging & Pemantauan
- `make logs` : Pantau realtime log seluruh container (Ctrl+C untuk keluar).
- `make logs-php` / `make logs-app` : Pantau log container PHP application.
- `make logs-nginx` : Pantau log web server Nginx.
- `make logs-db` : Pantau log database MySQL.
- `make logs-redis` : Pantau log container Redis.
- `make logs-pma` : Pantau log container phpMyAdmin.

---

## 🗄️ Kredensial Database Default Vel Engine

- **Host (dari Host OS)**: `127.0.0.1`
- **Host (dari dalam Container)**: `db`
- **Port Host**: `3405`
- **Database**: `machine`
- **Username**: `machine`
- **Password**: `secret`
- **Root Password**: `root`

*(Untuk projek di dalam folder `projects/`, kredensial database diatur otomatis sesuai nama projek dan dapat dilihat melalui `make info` di direktori projek tersebut).*

---

## 📄 Lisensi

Vel Engine didistribusikan di bawah lisensi [MIT](LICENSE).
