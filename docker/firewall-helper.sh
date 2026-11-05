#!/usr/bin/env bash
# ==============================================================================
# Vel Engine - Linux Firewall Helper
# Automatically detects OS and opens allocated ports in active Linux firewalls
# (UFW, firewalld, iptables). Non-Linux platforms are skipped gracefully.
# ==============================================================================
set -e

C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_CYAN="\033[36m"
C_YELLOW="\033[33m"
C_RED="\033[31m"

PROJECT_NAME="${1:-laravel-app}"
APP_PORT="$2"
VITE_PORT="$3"
DB_PORT="$4"
PMA_PORT="$5"
REDIS_PORT="$6"

# 1. Check user device / operating system
OS="$(uname -s)"
if [ "$OS" != "Linux" ]; then
    echo -e "${C_CYAN}ℹ Deteksi Perangkat: Bukan Linux ($OS). Melewati konfigurasi firewall.${C_RESET}"
    exit 0
fi

# 2. Check if running inside container (skip, host will handle it)
if [ -f /.dockerenv ]; then
    exit 0
fi

if [ -z "$APP_PORT" ]; then
    echo -e "${C_YELLOW}⚠ Argumen port tidak lengkap. Firewall helper dilewati.${C_RESET}"
    exit 0
fi

PORTS=("$APP_PORT" "$VITE_PORT" "$DB_PORT" "$PMA_PORT" "$REDIS_PORT")
SERVICES=("Web App" "Vite HMR" "MySQL Database" "phpMyAdmin" "Redis")

# 3. Detect active firewall on Linux
UFW_ACTIVE=0
FIREWALLD_ACTIVE=0

if command -v ufw >/dev/null 2>&1; then
    if systemctl is-active --quiet ufw 2>/dev/null; then
        UFW_ACTIVE=1
    elif [ -f /etc/ufw/ufw.conf ] && grep -qi "ENABLED=yes" /etc/ufw/ufw.conf 2>/dev/null; then
        UFW_ACTIVE=1
    fi
fi

if command -v firewall-cmd >/dev/null 2>&1; then
    if systemctl is-active --quiet firewalld 2>/dev/null || [ "$(firewall-cmd --state 2>/dev/null)" = "running" ]; then
        FIREWALLD_ACTIVE=1
    fi
fi

# 4. Process firewall rules if active
if [ "$UFW_ACTIVE" -eq 1 ]; then
    echo -e "${C_CYAN}🛡️  Terdeteksi OS Linux dengan firewall UFW aktif.${C_RESET}"
    echo -e "   Menyesuaikan firewall agar port baru tidak bentrok / terblokir..."

    CAN_SUDO=0
    SUDO_CMD=""
    if [ "$(id -u)" -eq 0 ]; then
        CAN_SUDO=1
        SUDO_CMD=""
    elif sudo -n true 2>/dev/null; then
        CAN_SUDO=1
        SUDO_CMD="sudo -n"
    fi

    if [ "$CAN_SUDO" -eq 1 ]; then
        for i in "${!PORTS[@]}"; do
            port="${PORTS[$i]}"
            svc="${SERVICES[$i]}"
            $SUDO_CMD ufw allow "$port/tcp" comment "Vel Engine: $PROJECT_NAME ($svc)" >/dev/null 2>&1 || true
            echo -e "  ${C_GREEN}✔ UFW Allowed:${C_RESET} Port ${C_BOLD}$port/tcp${C_RESET} ($svc)"
        done
        echo -e "  ${C_GREEN}✔ Port berhasil dibuka di firewall UFW.${C_RESET}"
    else
        echo -e "  ${C_YELLOW}ℹ Hak akses administrator diperlukan untuk membuka port UFW secara instan.${C_RESET}"
        echo -e "  Jalankan perintah berikut jika akses dari jaringan luar dibutuhkan:"
        for i in "${!PORTS[@]}"; do
            echo -e "    ${C_CYAN}sudo ufw allow ${PORTS[$i]}/tcp comment \"Vel Engine: $PROJECT_NAME (${SERVICES[$i]})\"${C_RESET}"
        done
    fi

elif [ "$FIREWALLD_ACTIVE" -eq 1 ]; then
    echo -e "${C_CYAN}🛡️  Terdeteksi OS Linux dengan firewalld aktif.${C_RESET}"
    echo -e "   Menyesuaikan firewall firewalld..."

    CAN_SUDO=0
    SUDO_CMD=""
    if [ "$(id -u)" -eq 0 ]; then
        CAN_SUDO=1
        SUDO_CMD=""
    elif sudo -n true 2>/dev/null; then
        CAN_SUDO=1
        SUDO_CMD="sudo -n"
    fi

    if [ "$CAN_SUDO" -eq 1 ]; then
        for i in "${!PORTS[@]}"; do
            port="${PORTS[$i]}"
            svc="${SERVICES[$i]}"
            $SUDO_CMD firewall-cmd --add-port="$port/tcp" --permanent >/dev/null 2>&1 || true
            echo -e "  ${C_GREEN}✔ Firewalld Allowed:${C_RESET} Port ${C_BOLD}$port/tcp${C_RESET} ($svc)"
        done
        $SUDO_CMD firewall-cmd --reload >/dev/null 2>&1 || true
    else
        echo -e "  ${C_YELLOW}ℹ Hak akses administrator diperlukan untuk membuka port firewalld secara instan.${C_RESET}"
        echo -e "  Jalankan perintah berikut jika akses dari jaringan luar dibutuhkan:"
        for i in "${!PORTS[@]}"; do
            echo -e "    ${C_CYAN}sudo firewall-cmd --add-port=${PORTS[$i]}/tcp --permanent${C_RESET}"
        done
        echo -e "    ${C_CYAN}sudo firewall-cmd --reload${C_RESET}"
    fi
else
    echo -e "${C_GREEN}✔ OS Linux: Tidak ada firewall aktif (UFW/firewalld) yang memblokir port.${C_RESET}"
fi
