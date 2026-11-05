#!/usr/bin/env bash
# ==============================================================================
# Laravel Docker Scaffolder
# Automatically scaffolds Docker environment (Nginx, PHP 8.4-FPM, MySQL 8.4,
# phpMyAdmin, Redis, Node/NPM) and complete Makefile for new Laravel projects.
# ==============================================================================
set -e

# Terminal styling
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_CYAN="\033[36m"
C_YELLOW="\033[33m"
C_RED="\033[31m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
MACHINE_DIR="$(dirname "$SCRIPT_DIR")"

# Locate templates directory (host or container)
TEMPLATES_DIR="$MACHINE_DIR/templates/project"
if [ ! -d "$TEMPLATES_DIR" ] && [ -d "/usr/local/share/laravel-docker-machine/templates/project" ]; then
    TEMPLATES_DIR="/usr/local/share/laravel-docker-machine/templates/project"
elif [ ! -d "$TEMPLATES_DIR" ] && [ -d "/var/www/html/templates/project" ]; then
    TEMPLATES_DIR="/var/www/html/templates/project"
fi

TARGET="${1:-.}"
# Resolve target directory
if [ -d "$TARGET" ]; then
    TARGET_DIR="$(cd "$TARGET" >/dev/null 2>&1 && pwd)"
elif [ -d "$PWD/$TARGET" ]; then
    TARGET_DIR="$(cd "$PWD/$TARGET" >/dev/null 2>&1 && pwd)"
else
    echo -e "${C_RED}Error: Direktori target '$TARGET' tidak ditemukan!${C_RESET}"
    exit 1
fi

PROJECT_NAME="$(basename "$TARGET_DIR")"

# Check if target is the machine root itself
if [ "$TARGET_DIR" = "$MACHINE_DIR" ] || [ "$PROJECT_NAME" = "machine" ]; then
    echo -e "${C_CYAN}Mengonfigurasi projek Laravel di root machine...${C_RESET}"
    if [ -f "$TARGET_DIR/.env" ]; then
        sed -i -E 's|^DB_CONNECTION=.*|DB_CONNECTION=mysql|' "$TARGET_DIR/.env" 2>/dev/null || true
        sed -i -E 's|^#?\s*DB_HOST=.*|DB_HOST=db|' "$TARGET_DIR/.env" 2>/dev/null || true
        sed -i -E 's|^#?\s*DB_PORT=.*|DB_PORT=3306|' "$TARGET_DIR/.env" 2>/dev/null || true
        sed -i -E 's|^#?\s*DB_DATABASE=.*|DB_DATABASE=machine|' "$TARGET_DIR/.env" 2>/dev/null || true
        sed -i -E 's|^#?\s*DB_USERNAME=.*|DB_USERNAME=machine|' "$TARGET_DIR/.env" 2>/dev/null || true
        sed -i -E 's|^#?\s*DB_PASSWORD=.*|DB_PASSWORD=secret|' "$TARGET_DIR/.env" 2>/dev/null || true
        sed -i -E 's|^#?\s*REDIS_HOST=.*|REDIS_HOST=redis|' "$TARGET_DIR/.env" 2>/dev/null || true
        sed -i -E 's|^#?\s*REDIS_PORT=.*|REDIS_PORT=6379|' "$TARGET_DIR/.env" 2>/dev/null || true
    fi
    chmod -R 775 "$TARGET_DIR/storage" "$TARGET_DIR/bootstrap/cache" 2>/dev/null || true
    echo -e "${C_GREEN}✔ Root machine siap digunakan.${C_RESET}"
    exit 0
fi

# Normalized project identifiers
COMPOSE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+|-+$//g')
DB_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g' | sed -E 's/^_+|_+$//g')

[ -z "$COMPOSE_NAME" ] && COMPOSE_NAME="laravel-app"
[ -z "$DB_NAME" ] && DB_NAME="laravel_app"

# Function to find next available port
find_port() {
    local base_port=$1
    local exclude_ports="$2"

    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import socket
start = $base_port
excluded = [int(p) for p in '$exclude_ports'.split() if p.isdigit()]
for p in range(start, start + 100):
    if p in excluded:
        continue
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind(('0.0.0.0', p))
            print(p)
            break
        except OSError:
            continue
"
    elif command -v php >/dev/null 2>&1; then
        php -r "
\$start = $base_port;
\$excluded = array_filter(explode(' ', '$exclude_ports'));
for (\$p = \$start; \$p < \$start + 100; \$p++) {
    if (in_array(\$p, \$excluded)) continue;
    \$s = @stream_socket_server('tcp://0.0.0.0:' . \$p);
    if (\$s) {
        fclose(\$s);
        echo \$p;
        break;
    }
}
"
    else
        echo "$base_port"
    fi
}

echo -e "${C_CYAN}Memeriksa dan mengalokasikan port Docker yang tersedia...${C_RESET}"
APP_PORT=$(find_port 8000 "")
VITE_PORT=$(find_port 5173 "$APP_PORT")
DB_PORT=$(find_port 3306 "$APP_PORT $VITE_PORT")
PMA_PORT=$(find_port 8080 "$APP_PORT $VITE_PORT $DB_PORT")
REDIS_PORT=$(find_port 6379 "$APP_PORT $VITE_PORT $DB_PORT $PMA_PORT")

echo -e "  • APP_PORT   : ${C_BOLD}$APP_PORT${C_RESET}"
echo -e "  • VITE_PORT  : ${C_BOLD}$VITE_PORT${C_RESET}"
echo -e "  • DB_PORT    : ${C_BOLD}$DB_PORT${C_RESET}"
echo -e "  • PMA_PORT   : ${C_BOLD}$PMA_PORT${C_RESET}"
echo -e "  • REDIS_PORT : ${C_BOLD}$REDIS_PORT${C_RESET}"

# 1. Copy docker folders & configs
echo -e "${C_CYAN}Menyusun struktur Docker untuk '$PROJECT_NAME'...${C_RESET}"
mkdir -p "$TARGET_DIR/docker/nginx" "$TARGET_DIR/docker/php"

cp "$TEMPLATES_DIR/docker/nginx/default.conf" "$TARGET_DIR/docker/nginx/default.conf"
cp "$TEMPLATES_DIR/docker/php/php.ini" "$TARGET_DIR/docker/php/php.ini"
cp "$TEMPLATES_DIR/docker/entrypoint.sh" "$TARGET_DIR/docker/entrypoint.sh"
chmod +x "$TARGET_DIR/docker/entrypoint.sh"
cp "$TEMPLATES_DIR/.dockerignore" "$TARGET_DIR/.dockerignore"
cp "$TEMPLATES_DIR/Dockerfile.stub" "$TARGET_DIR/Dockerfile"

# 2. Render docker-compose.yml
sed -e "s/__COMPOSE_NAME__/$COMPOSE_NAME/g" \
    -e "s/__PROJECT_NAME__/$PROJECT_NAME/g" \
    -e "s/__DB_NAME__/$DB_NAME/g" \
    -e "s/__APP_PORT__/$APP_PORT/g" \
    -e "s/__VITE_PORT__/$VITE_PORT/g" \
    -e "s/__DB_PORT__/$DB_PORT/g" \
    -e "s/__PMA_PORT__/$PMA_PORT/g" \
    -e "s/__REDIS_PORT__/$REDIS_PORT/g" \
    "$TEMPLATES_DIR/docker-compose.yml.stub" > "$TARGET_DIR/docker-compose.yml"

# 3. Render Makefile
sed -e "s/__COMPOSE_NAME__/$COMPOSE_NAME/g" \
    -e "s/__PROJECT_NAME__/$PROJECT_NAME/g" \
    -e "s/__DB_NAME__/$DB_NAME/g" \
    -e "s/__APP_PORT__/$APP_PORT/g" \
    -e "s/__VITE_PORT__/$VITE_PORT/g" \
    -e "s/__DB_PORT__/$DB_PORT/g" \
    -e "s/__PMA_PORT__/$PMA_PORT/g" \
    -e "s/__REDIS_PORT__/$REDIS_PORT/g" \
    "$TEMPLATES_DIR/Makefile.stub" > "$TARGET_DIR/Makefile"

# 4. Helper function to configure .env files
configure_env() {
    local env_file="$1"
    [ ! -f "$env_file" ] && return 0

    # Ensure APP_URL
    if grep -q "^APP_URL=" "$env_file"; then
        sed -i -E "s|^APP_URL=.*|APP_URL=http://localhost:$APP_PORT|" "$env_file"
    else
        echo "APP_URL=http://localhost:$APP_PORT" >> "$env_file"
    fi

    # Database settings
    if grep -q "^DB_CONNECTION=" "$env_file"; then
        sed -i -E "s|^DB_CONNECTION=.*|DB_CONNECTION=mysql|" "$env_file"
    elif grep -q "^# DB_CONNECTION=" "$env_file"; then
        sed -i -E "s|^# DB_CONNECTION=.*|DB_CONNECTION=mysql|" "$env_file"
    else
        echo "DB_CONNECTION=mysql" >> "$env_file"
    fi

    if grep -q "^DB_HOST=" "$env_file" || grep -q "^# DB_HOST=" "$env_file"; then
        sed -i -E "s|^#?\s*DB_HOST=.*|DB_HOST=db|" "$env_file"
    else
        echo "DB_HOST=db" >> "$env_file"
    fi

    if grep -q "^DB_PORT=" "$env_file" || grep -q "^# DB_PORT=" "$env_file"; then
        sed -i -E "s|^#?\s*DB_PORT=.*|DB_PORT=3306|" "$env_file"
    else
        echo "DB_PORT=3306" >> "$env_file"
    fi

    if grep -q "^DB_DATABASE=" "$env_file" || grep -q "^# DB_DATABASE=" "$env_file"; then
        sed -i -E "s|^#?\s*DB_DATABASE=.*|DB_DATABASE=$DB_NAME|" "$env_file"
    else
        echo "DB_DATABASE=$DB_NAME" >> "$env_file"
    fi

    if grep -q "^DB_USERNAME=" "$env_file" || grep -q "^# DB_USERNAME=" "$env_file"; then
        sed -i -E "s|^#?\s*DB_USERNAME=.*|DB_USERNAME=$DB_NAME|" "$env_file"
    else
        echo "DB_USERNAME=$DB_NAME" >> "$env_file"
    fi

    if grep -q "^DB_PASSWORD=" "$env_file" || grep -q "^# DB_PASSWORD=" "$env_file"; then
        sed -i -E "s|^#?\s*DB_PASSWORD=.*|DB_PASSWORD=secret|" "$env_file"
    else
        echo "DB_PASSWORD=secret" >> "$env_file"
    fi

    # Redis settings
    if grep -q "^REDIS_HOST=" "$env_file" || grep -q "^# REDIS_HOST=" "$env_file"; then
        sed -i -E "s|^#?\s*REDIS_HOST=.*|REDIS_HOST=redis|" "$env_file"
    else
        echo "REDIS_HOST=redis" >> "$env_file"
    fi

    if grep -q "^REDIS_PORT=" "$env_file" || grep -q "^# REDIS_PORT=" "$env_file"; then
        sed -i -E "s|^#?\s*REDIS_PORT=.*|REDIS_PORT=6379|" "$env_file"
    else
        echo "REDIS_PORT=6379" >> "$env_file"
    fi

    if grep -q "^REDIS_CLIENT=" "$env_file" || grep -q "^# REDIS_CLIENT=" "$env_file"; then
        sed -i -E "s|^#?\s*REDIS_CLIENT=.*|REDIS_CLIENT=phpredis|" "$env_file"
    else
        echo "REDIS_CLIENT=phpredis" >> "$env_file"
    fi

    # Cache & Sessions
    sed -i -E "s|^CACHE_STORE=.*|CACHE_STORE=redis|" "$env_file" 2>/dev/null || true
    sed -i -E "s|^SESSION_DRIVER=.*|SESSION_DRIVER=redis|" "$env_file" 2>/dev/null || true
    sed -i -E "s|^QUEUE_CONNECTION=.*|QUEUE_CONNECTION=redis|" "$env_file" 2>/dev/null || true

    # Append Docker Port Mapping section if not present
    if ! grep -q "COMPOSE_PROJECT_NAME=" "$env_file"; then
        cat <<EOT >> "$env_file"

# ==============================================================================
# Docker Configuration & Port Mapping
# ==============================================================================
COMPOSE_PROJECT_NAME=$COMPOSE_NAME
APP_PORT=$APP_PORT
VITE_PORT=$VITE_PORT
DB_PORT=$DB_PORT
DB_ROOT_PASSWORD=root
PMA_PORT=$PMA_PORT
REDIS_PORT=$REDIS_PORT
EOT
    fi
}

echo -e "${C_CYAN}Menyesuaikan konfigurasi database & redis di .env...${C_RESET}"
configure_env "$TARGET_DIR/.env"
configure_env "$TARGET_DIR/.env.example"

# 5. Optimize vite.config.js for Docker HMR if present
if [ -f "$TARGET_DIR/vite.config.js" ]; then
    if grep -q "server:" "$TARGET_DIR/vite.config.js"; then
        if ! grep -q "host:[[:space:]]*['\"]0\.0\.0\.0['\"]" "$TARGET_DIR/vite.config.js"; then
            sed -i -E "s|server:[[:space:]]*\{|server: {\n        host: '0.0.0.0',\n        port: 5173,\n        hmr: {\n            host: 'localhost',\n        },|" "$TARGET_DIR/vite.config.js" 2>/dev/null || true
        fi
    else
        sed -i -E "s|defineConfig\(\{([[:space:]]*)|defineConfig({\n    server: {\n        host: '0.0.0.0',\n        port: 5173,\n        hmr: {\n            host: 'localhost',\n        },\n    },\1|" "$TARGET_DIR/vite.config.js" 2>/dev/null || true
    fi
fi

# 6. Set proper directory permissions
chmod -R 775 "$TARGET_DIR/storage" "$TARGET_DIR/bootstrap/cache" 2>/dev/null || true

# 7. Print summary banner
echo ""
echo -e "  ${C_BOLD}${C_GREEN}════════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "  ${C_BOLD}${C_GREEN}🎉 SETUP DOCKER & MAKEFILE BERHASIL DIBUAT UNTUK: ${C_CYAN}$PROJECT_NAME${C_RESET}"
echo -e "  ${C_BOLD}${C_GREEN}════════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "  ${C_BOLD}Layanan & Alokasi Port:${C_RESET}"
echo -e "    • Web Application (Nginx) : ${C_GREEN}http://localhost:$APP_PORT${C_RESET}"
echo -e "    • phpMyAdmin (GUI DB)     : ${C_GREEN}http://localhost:$PMA_PORT${C_RESET}"
echo -e "    • Vite Dev Server (HMR)   : ${C_GREEN}http://localhost:$VITE_PORT${C_RESET}"
echo -e "    • MySQL Database Server   : ${C_CYAN}127.0.0.1:$DB_PORT${C_RESET} (Internal: db:3306)"
echo -e "    • Redis Cache & Queue     : ${C_CYAN}127.0.0.1:$REDIS_PORT${C_RESET} (Internal: redis:6379)"
echo -e "    • PHP-FPM Service         : ${C_CYAN}PHP 8.4 + Composer + Node 22 + NPM${C_RESET}"
echo ""
echo -e "  ${C_BOLD}Kredensial Database Default:${C_RESET}"
echo -e "    • Database : ${C_CYAN}$DB_NAME${C_RESET}"
echo -e "    • Username : ${C_CYAN}$DB_NAME${C_RESET}"
echo -e "    • Password : ${C_CYAN}secret${C_RESET}"
echo -e "    • Root     : ${C_CYAN}root${C_RESET}"
echo ""
echo -e "  ${C_BOLD}Langkah Menjalankan Projek Baru:${C_RESET}"
REL_DIR="$PROJECT_NAME"
if [ -d "$PWD/projects/$PROJECT_NAME" ] || [ -d "$MACHINE_DIR/projects/$PROJECT_NAME" ]; then
    REL_DIR="projects/$PROJECT_NAME"
fi
echo -e "    ${C_YELLOW}cd $REL_DIR${C_RESET}"
echo -e "    ${C_YELLOW}make up${C_RESET}            # Jalankan stack container di background"
echo -e "    ${C_YELLOW}make shell-php${C_RESET}     # Masuk ke container PHP (developer)"
echo -e "    ${C_YELLOW}make shell-db${C_RESET}      # Masuk ke container MySQL"
echo -e "    ${C_YELLOW}make dev${C_RESET}           # Jalankan Vite HMR server"
echo -e "    ${C_YELLOW}make info${C_RESET}          # Tampilkan info URL & port kapan saja"
echo -e "  ${C_BOLD}${C_GREEN}════════════════════════════════════════════════════════════════════${C_RESET}"
echo ""
