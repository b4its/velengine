# ==============================================================================
# Laravel Docker Machine — Makefile
# Setup PHP 8.4 + Laravel CLI + MySQL + Redis + phpMyAdmin + Node/NPM
# Seluruh port dikonfigurasi: {Port Standar} + 99
# ==============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Load variabel dari file .env jika ada
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# --- Konfigurasi Port Default (Standar + 99) -----------------------------------
APP_PORT     ?= 8099
VITE_PORT    ?= 5272
DB_PORT      ?= 3405
PMA_PORT     ?= 8179
REDIS_PORT   ?= 6478

DB_DATABASE  ?= machine
DB_USERNAME  ?= machine
DB_PASSWORD  ?= secret

COMPOSE      ?= docker compose
APP_SERVICE  ?= app
PROJECT_DIR  ?= .

# Tentukan direktori kerja aplikasi di dalam container
ifeq ($(strip $(PROJECT_DIR)),.)
    APP_WORK_DIR := /var/www/html
else
    APP_WORK_DIR := /var/www/html/$(strip $(PROJECT_DIR))
endif

# Styling Output Terminal (ANSI Escape Codes Standar)
C_RESET  := \033[0m
C_BOLD   := \033[1m
C_GREEN  := \033[32m
C_CYAN   := \033[36m
C_YELLOW := \033[33m
C_RED    := \033[31m

# Deteksi TTY untuk perintah docker compose exec
INTERACTIVE := $(shell [ -t 0 ] && [ -t 1 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE),1)
    DOCKER_EXEC := $(COMPOSE) exec
else
    DOCKER_EXEC := $(COMPOSE) exec -T
endif

DOCKER_APP_EXEC := $(DOCKER_EXEC) -w $(APP_WORK_DIR) $(APP_SERVICE)

# ==============================================================================
# HELP (Default)
# ==============================================================================
.PHONY: help
help: ## Tampilkan daftar lengkap perintah yang tersedia
	@echo ""
	@echo -e "  $(C_BOLD)$(C_CYAN)🚀 Laravel Docker Machine // Command Center$(C_RESET)"
	@echo -e "  $(C_YELLOW)Port Formula: {Port Standar} + 99$(C_RESET)"
	@echo "  ──────────────────────────────────────────────────────────────────"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / { \
		printf "  \033[32m%-22s\033[0m %s\n", $$1, $$2 \
	}' $(MAKEFILE_LIST)
	@echo ""
	@echo -e "  $(C_BOLD)Contoh Pemakaian:$(C_RESET)"
	@echo "    make up                     # Nyalakan stack docker di background"
	@echo "    make new PROJECT=toko-kita  # Buat projek Laravel baru (disimpan di projects/)"
	@echo "    make new-here               # Inisialisasi projek Laravel langsung di folder saat ini"
	@echo "    make shell-php              # Masuk ke interactive terminal container PHP"
	@echo "    make shell-db               # Masuk ke interactive bash container MySQL"
	@echo "    make mysql                  # Masuk langsung ke interactive MySQL CLI"
	@echo "    make dev                    # Jalankan Vite HMR server"
	@echo "    make info                   # Tampilkan URL & info port lengkap"
	@echo ""

# ==============================================================================
# LIFECYCLE & CONTAINER MANAGEMENT
# ==============================================================================
.PHONY: up
up: env ## Nyalakan seluruh stack docker di background
	@echo -e "$(C_CYAN)🚀 Menyalakan seluruh service Docker...$(C_RESET)"
	$(COMPOSE) up -d --build
	@echo -e "$(C_GREEN)✔ Stack berhasil berjalan!$(C_RESET)"
	@echo -e "  • Web App    : $(C_BOLD)http://localhost:$(APP_PORT)$(C_RESET)"
	@echo -e "  • phpMyAdmin : $(C_BOLD)http://localhost:$(PMA_PORT)$(C_RESET)"
	@echo -e "  • Vite Dev   : $(C_BOLD)http://localhost:$(VITE_PORT)$(C_RESET)"
	@echo -e "  • MySQL Host : $(C_BOLD)127.0.0.1:$(DB_PORT)$(C_RESET)"

.PHONY: down
down: ## Matikan seluruh container (volume data tetap aman)
	@echo -e "$(C_YELLOW)🛑 Menghentikan seluruh container...$(C_RESET)"
	$(COMPOSE) down
	@echo -e "$(C_GREEN)✔ Seluruh container telah dimatikan.$(C_RESET)"

.PHONY: down-v
down-v: ## Matikan container dan HAPUS SELURUH VOLUME database (Destruktif!)
	@echo -e "$(C_RED)⚠ Menghapus seluruh container & volume database...$(C_RESET)"
	$(COMPOSE) down -v --remove-orphans
	@echo -e "$(C_GREEN)✔ Volume database & container telah dibersihkan.$(C_RESET)"

.PHONY: restart
restart: ## Restart seluruh service container
	@echo -e "$(C_CYAN)🔄 Me-restart seluruh container...$(C_RESET)"
	$(COMPOSE) restart
	@echo -e "$(C_GREEN)✔ Seluruh container berhasil di-restart.$(C_RESET)"

.PHONY: build
build: ## Build ulang image container
	$(COMPOSE) build

.PHONY: rebuild
rebuild: ## Build ulang image container dari awal (tanpa cache)
	$(COMPOSE) build --no-cache

# ==============================================================================
# STATUS & INFORMASI
# ==============================================================================
.PHONY: ps status
status: ## Tampilkan status terkini container, healthcheck, dan alokasi port
	@echo ""
	@echo -e "  $(C_BOLD)$(C_CYAN)📊 Status Container & Port Mapping$(C_RESET)"
	@echo "  ──────────────────────────────────────────────────────────────────"
	@$(COMPOSE) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	@echo ""

ps: status

.PHONY: info
info: ## Tampilkan informasi lengkap port ({port}+99), URL, dan versi tools
	@echo ""
	@echo -e "  $(C_BOLD)$(C_CYAN)📌 INFORMASI SETUP & PORT ({Port Standar} + 99)$(C_RESET)"
	@echo "  ──────────────────────────────────────────────────────────────────"
	@printf "  %-24s : \033[32m%s\033[0m (Standar: 8000 + 99)\n" "Web Application" "http://localhost:$(APP_PORT)"
	@printf "  %-24s : \033[32m%s\033[0m (Standar: 8080 + 99)\n" "phpMyAdmin" "http://localhost:$(PMA_PORT)"
	@printf "  %-24s : \033[32m%s\033[0m (Standar: 5173 + 99)\n" "Vite Dev Server" "http://localhost:$(VITE_PORT)"
	@printf "  %-24s : \033[32m%s\033[0m (Standar: 3306 + 99)\n" "MySQL Database" "127.0.0.1:$(DB_PORT)"
	@printf "  %-24s : \033[32m%s\033[0m (Standar: 6379 + 99)\n" "Redis Cache" "127.0.0.1:$(REDIS_PORT)"
	@echo "  ──────────────────────────────────────────────────────────────────"
	@echo -e "  $(C_BOLD)Kredensial Database:$(C_RESET)"
	@echo "    Database  : $(DB_DATABASE)"
	@echo "    Username  : $(DB_USERNAME)"
	@echo "    Password  : $(DB_PASSWORD)"
	@echo "    Root Pass : root"
	@echo "  ──────────────────────────────────────────────────────────────────"
	@echo -e "  $(C_BOLD)Versi Perangkat Lunak di Container:$(C_RESET)"
	@if $(COMPOSE) ps --status running --services 2>/dev/null | grep -qx "$(APP_SERVICE)"; then \
		echo -n "    PHP               : "; $(DOCKER_EXEC) $(APP_SERVICE) php -r "echo PHP_VERSION . PHP_EOL;"; \
		echo -n "    Laravel Installer : "; $(DOCKER_EXEC) $(APP_SERVICE) laravel --version 2>/dev/null || echo "Tersedia"; \
		echo -n "    Composer          : "; $(DOCKER_EXEC) $(APP_SERVICE) composer --version --no-ansi 2>/dev/null | grep -m1 "Composer version" | cut -d' ' -f1-3 || echo "Tersedia"; \
		echo -n "    Node.js           : "; $(DOCKER_EXEC) $(APP_SERVICE) node -v; \
		echo -n "    NPM               : "; $(DOCKER_EXEC) $(APP_SERVICE) npm -v; \
	else \
		echo "    (Nyalakan stack dengan 'make up' untuk melihat rincian versi)"; \
	fi
	@echo ""

# ==============================================================================
# LARAVEL PROJECT CREATION & AUTO-SCAFFOLD
# ==============================================================================
.PHONY: new
new: ## Buat projek Laravel baru di dalam folder projects/ (Contoh: make new PROJECT=nama_projek)
	@mkdir -p projects
	@if [ -z "$(PROJECT)" ]; then \
		echo "$(C_YELLOW)Silakan tentukan nama projek:$(C_RESET)"; \
		read -p "Nama projek Laravel: " p_name; \
	else \
		p_name="$(PROJECT)"; \
	fi; \
	if [ -z "$$p_name" ]; then \
		echo "$(C_RED)Nama projek tidak boleh kosong!$(C_RESET)"; exit 1; \
	fi; \
	clean_name=$$(echo "$$p_name" | awk '{print $$1}' | sed 's|^projects/||'); \
	extra_args=$$(echo "$$p_name" | cut -d' ' -f2-); \
	if [ "$$clean_name" = "$$extra_args" ]; then extra_args=""; fi; \
	echo "$(C_CYAN)🚀 Menjalankan 'laravel new $$clean_name' di dalam folder projects/...$(C_RESET)"; \
	if $(COMPOSE) ps --status running --services 2>/dev/null | grep -qx "$(APP_SERVICE)"; then \
		$(COMPOSE) exec -it -w /var/www/html/projects $(APP_SERVICE) laravel new "$$clean_name" $$extra_args $(ARGS); \
	else \
		$(COMPOSE) run --rm -it -w /var/www/html/projects $(APP_SERVICE) laravel new "$$clean_name" $$extra_args $(ARGS); \
	fi; \
	if [ -d "projects/$$clean_name" ] && [ ! -f "projects/$$clean_name/docker-compose.yml" ]; then \
		./docker/scaffold-project.sh "projects/$$clean_name"; \
	fi

.PHONY: new-here
new-here: ## Buat projek Laravel langsung di folder saat ini (laravel new .)
	@echo "$(C_CYAN)🚀 Menjalankan 'laravel new .' langsung di root directory...$(C_RESET)"
	@if $(COMPOSE) ps --status running --services 2>/dev/null | grep -qx "$(APP_SERVICE)"; then \
		$(COMPOSE) exec -it $(APP_SERVICE) laravel new . ; \
	else \
		$(COMPOSE) run --rm -it $(APP_SERVICE) laravel new . ; \
	fi; \
	./docker/scaffold-project.sh .

# ==============================================================================
# SHELL ACCESS
# ==============================================================================
.PHONY: shell-php shell
shell-php: ## Buka interactive bash shell di container PHP sebagai developer
	@if ! $(COMPOSE) ps --status running --services 2>/dev/null | grep -qx "$(APP_SERVICE)"; then \
		echo -e "$(C_YELLOW)Container belum berjalan, menyalakan stack terlebih dahulu...$(C_RESET)"; \
		$(COMPOSE) up -d; \
	fi
	$(DOCKER_APP_EXEC) bash

shell: shell-php ## Alias untuk make shell-php

.PHONY: shell-php-root root
shell-php-root: ## Buka interactive bash shell di container PHP sebagai ROOT
	$(DOCKER_EXEC) -u 0 -w $(APP_WORK_DIR) $(APP_SERVICE) bash

root: shell-php-root ## Alias untuk make shell-php-root

.PHONY: shell-db
shell-db: ## Buka interactive bash terminal di container MySQL Database
	$(DOCKER_EXEC) db bash

.PHONY: mysql db-cli
mysql: ## Buka interactive MySQL CLI prompt
	$(DOCKER_EXEC) db mysql -u$(DB_USERNAME) -p$(DB_PASSWORD) $(DB_DATABASE)

db-cli: mysql ## Alias untuk make mysql

.PHONY: shell-nginx
shell-nginx: ## Buka terminal shell di container Nginx
	$(DOCKER_EXEC) nginx sh

.PHONY: shell-redis redis-cli
shell-redis: ## Buka interactive redis-cli di container Redis
	$(DOCKER_EXEC) redis redis-cli

redis-cli: shell-redis ## Alias untuk make shell-redis

# ==============================================================================
# DEVELOPER TOOLS, ARTISAN, COMPOSER & NPM
# ==============================================================================
.PHONY: artisan art
artisan: ## Jalankan perintah php artisan (Contoh: make artisan cmd="migrate")
	@$(DOCKER_APP_EXEC) php artisan $(cmd)

art: ## Alias untuk make artisan
	@$(DOCKER_APP_EXEC) php artisan $(cmd)

.PHONY: composer
composer: ## Jalankan perintah composer (Contoh: make composer cmd="require filament/filament")
	@$(DOCKER_APP_EXEC) composer $(cmd)

.PHONY: npm
npm: ## Jalankan perintah npm (Contoh: make npm cmd="install")
	@$(DOCKER_APP_EXEC) npm $(cmd)

.PHONY: dev
dev: ## Jalankan Vite development server (HMR)
	@echo -e "$(C_CYAN)🚀 Menjalankan Vite dev server di http://localhost:$(VITE_PORT)...$(C_RESET)"
	$(DOCKER_APP_EXEC) npm run dev -- --host 0.0.0.0 --port 5173

.PHONY: build-assets
build-assets: ## Build frontend assets untuk production (npm run build)
	$(DOCKER_APP_EXEC) npm run build

.PHONY: tinker
tinker: ## Buka Laravel Interactive Tinker Shell
	$(DOCKER_APP_EXEC) php artisan tinker

.PHONY: test
test: ## Jalankan unit test / Pest / PHPUnit
	$(DOCKER_APP_EXEC) php artisan test

.PHONY: migrate
migrate: ## Jalankan migrasi database
	$(DOCKER_APP_EXEC) php artisan migrate

.PHONY: migrate-fresh
migrate-fresh: ## Reset database dan jalankan ulang semua migrasi + seeder
	$(DOCKER_APP_EXEC) php artisan migrate:fresh --seed

.PHONY: migrate-rollback
migrate-rollback: ## Rollback batch migrasi terakhir
	$(DOCKER_APP_EXEC) php artisan migrate:rollback

.PHONY: seed
seed: ## Jalankan database seeder (php artisan db:seed)
	$(DOCKER_APP_EXEC) php artisan db:seed

.PHONY: key
key: ## Generate application key baru
	$(DOCKER_APP_EXEC) php artisan key:generate

.PHONY: storage-link
storage-link: ## Buat symbolic link public storage
	$(DOCKER_APP_EXEC) php artisan storage:link

.PHONY: clear
clear: ## Bersihkan seluruh cache aplikasi Laravel (config, route, view, event)
	$(DOCKER_APP_EXEC) php artisan optimize:clear

.PHONY: optimize
optimize: ## Cache config, route, dan view untuk performa maksimal
	$(DOCKER_APP_EXEC) php artisan optimize

.PHONY: perm
perm: ## Perbaiki hak akses direktori storage dan bootstrap/cache
	@echo -e "$(C_CYAN)Mengatur hak akses storage & bootstrap/cache...$(C_RESET)"
	$(COMPOSE) exec -u 0 $(APP_SERVICE) chown -R 1000:1000 $(APP_WORK_DIR)/storage $(APP_WORK_DIR)/bootstrap/cache 2>/dev/null || true
	$(COMPOSE) exec -u 0 $(APP_SERVICE) chmod -R 775 $(APP_WORK_DIR)/storage $(APP_WORK_DIR)/bootstrap/cache 2>/dev/null || true
	@echo -e "$(C_GREEN)✔ Hak akses berhasil diperbaiki.$(C_RESET)"

# ==============================================================================
# LOGS & MONITORING
# ==============================================================================
.PHONY: logs
logs: ## Pantau log seluruh container (Ctrl+C untuk keluar)
	$(COMPOSE) logs -f --tail=100

.PHONY: logs-php logs-app
logs-php: ## Pantau log container PHP
	$(COMPOSE) logs -f --tail=100 $(APP_SERVICE)

logs-app: logs-php ## Alias untuk make logs-php

.PHONY: logs-nginx
logs-nginx: ## Pantau log Nginx
	$(COMPOSE) logs -f --tail=100 nginx

.PHONY: logs-db
logs-db: ## Pantau log MySQL Database
	$(COMPOSE) logs -f --tail=100 db

.PHONY: logs-redis
logs-redis: ## Pantau log Redis
	$(COMPOSE) logs -f --tail=100 redis

.PHONY: logs-pma
logs-pma: ## Pantau log phpMyAdmin
	$(COMPOSE) logs -f --tail=100 phpmyadmin

# ==============================================================================
# ENVIRONMENT SETUP
# ==============================================================================
.PHONY: env
env: ## Buat file .env dari .env.example bila belum ada
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(C_GREEN)✔ File .env dibuat dari .env.example$(C_RESET)"; \
	fi
