#!/usr/bin/env bash
# ==============================================================================
# Vel Engine - Laravel Engine Scaffolder
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

# ==============================================================================
# Random Non-System Port Generation (15000 - 49999)
# Actively eliminates all ports registered in:
# 1. 'docker ps -a' mapped ports
# 2. 'ss -tuln' active listening ports
# 3. Linux kernel /proc/net/tcp and /proc/net/tcp6
# 4. Configured .env files in projects/ and root
# 5. Core/system reserved ports (<1024, 3306, 5432, 6379, 8000, 8080, 5173, etc.)
# ==============================================================================
get_random_ports() {
    local base_dir="$MACHINE_DIR"
    if [ ! -d "$base_dir" ]; then
        base_dir="."
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import subprocess, re, glob, os, random, socket

excluded = set()

# 1. Reserved / core system ports (<1024 and common server ports)
RESERVED = {
    21, 22, 23, 25, 53, 80, 443, 3000, 3001, 3306, 3307, 3405, 3514, 5000, 5173, 5272, 
    5296, 5432, 5434, 5558, 6379, 6380, 6478, 6505, 8000, 8001, 8002, 8080, 8081, 8099, 
    8179, 8422, 9000, 27017, 33060
}
excluded.update(RESERVED)

# 2. Extract ports registered in 'docker ps -a'
try:
    res = subprocess.check_output(['docker', 'ps', '-a', '--format', '{{.Ports}}'], text=True, stderr=subprocess.DEVNULL)
    for p in re.findall(r':(\d+)->', res):
        excluded.add(int(p))
except Exception:
    pass

# 3. Extract active listening ports via 'ss -tuln'
try:
    res = subprocess.check_output(['ss', '-tuln'], text=True, stderr=subprocess.DEVNULL)
    for p in re.findall(r':(\d+)\s+', res):
        excluded.add(int(p))
except Exception:
    pass

# 4. Extract listening ports from Linux kernel /proc/net/tcp & tcp6
for proc_path in ['/proc/net/tcp', '/proc/net/tcp6']:
    try:
        with open(proc_path) as f:
            for line in f.readlines()[1:]:
                parts = line.strip().split()
                if len(parts) > 1:
                    port_hex = parts[1].split(':')[1]
                    excluded.add(int(port_hex, 16))
    except Exception:
        pass

# 5. Extract ports configured in existing projects/*/.env and ./.env
base_dir = '$base_dir'
env_patterns = [
    os.path.join(base_dir, 'projects', '*', '.env'),
    os.path.join(base_dir, 'projects', '*', '.env.example'),
    os.path.join(base_dir, '.env'),
    os.path.join(base_dir, '.env.example'),
]
for pattern in env_patterns:
    for env_file in glob.glob(pattern):
        try:
            with open(env_file) as f:
                for line in f:
                    m = re.search(r'_PORT=(\d+)', line)
                    if m:
                        excluded.add(int(m.group(1)))
        except Exception:
            pass

def pick_port(alloc):
    for _ in range(3000):
        p = random.randint(15000, 49999)
        if p in excluded or p in alloc or p < 1024:
            continue
        # Socket bind test 0.0.0.0
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                s.bind(('0.0.0.0', p))
            except OSError:
                excluded.add(p)
                continue
        # Socket bind test 127.0.0.1
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                s.bind(('127.0.0.1', p))
            except OSError:
                excluded.add(p)
                continue
        alloc.add(p)
        return p
    return random.randint(15000, 49999)

alloc = set()
ports = [pick_port(alloc) for _ in range(5)]
print(' '.join(str(p) for p in ports))
"
    elif command -v php >/dev/null 2>&1; then
        php -r "
\$excluded = array_flip([
    21, 22, 23, 25, 53, 80, 443, 3000, 3001, 3306, 3307, 3405, 3514, 5000, 5173, 5272, 
    5296, 5432, 5434, 5558, 6379, 6380, 6478, 6505, 8000, 8001, 8002, 8080, 8081, 8099, 
    8179, 8422, 9000, 27017, 33060
]);

// 1. Docker ps -a
\$docker_out = @shell_exec('docker ps -a --format \"{{.Ports}}\" 2>/dev/null');
if (\$docker_out && preg_match_all('/:(\d+)->/', \$docker_out, \$matches)) {
    foreach (\$matches[1] as \$p) \$excluded[(int)\$p] = true;
}

// 2. ss -tuln
\$ss_out = @shell_exec('ss -tuln 2>/dev/null');
if (\$ss_out && preg_match_all('/:(\d+)\s+/', \$ss_out, \$matches)) {
    foreach (\$matches[1] as \$p) \$excluded[(int)\$p] = true;
}

// 3. /proc/net/tcp & tcp6
foreach (['/proc/net/tcp', '/proc/net/tcp6'] as \$proc_path) {
    if (file_exists(\$proc_path)) {
        \$lines = @file(\$proc_path);
        if (\$lines) {
            foreach (array_slice(\$lines, 1) as \$line) {
                \$parts = preg_split('/\s+/', trim(\$line));
                if (isset(\$parts[1])) {
                    \$addr = explode(':', \$parts[1]);
                    if (isset(\$addr[1])) {
                        \$excluded[hexdec(\$addr[1])] = true;
                    }
                }
            }
        }
    }
}

// 4. Configured .env files
\$base_dir = '$base_dir';
\$env_files = array_merge(
    glob(\$base_dir . '/projects/*/.env') ?: [],
    glob(\$base_dir . '/projects/*/.env.example') ?: [],
    glob(\$base_dir . '/.env') ?: [],
    glob(\$base_dir . '/.env.example') ?: []
);
foreach (\$env_files as \$ef) {
    \$content = @file_get_contents(\$ef);
    if (\$content && preg_match_all('/_PORT=(\d+)/', \$content, \$matches)) {
        foreach (\$matches[1] as \$p) \$excluded[(int)\$p] = true;
    }
}

function pick_port(&\$excluded) {
    for (\$i = 0; \$i < 3000; \$i++) {
        \$p = rand(15000, 49999);
        if (\$p < 1024 || isset(\$excluded[\$p])) continue;
        \$s = @stream_socket_server('tcp://0.0.0.0:' . \$p);
        if (\$s) {
            fclose(\$s);
            \$excluded[\$p] = true;
            return \$p;
        }
        \$excluded[\$p] = true;
    }
    return rand(15000, 49999);
}

\$ports = [];
for (\$i = 0; \$i < 5; \$i++) {
    \$ports[] = pick_port(\$excluded);
}
echo implode(' ', \$ports);
"
    else
        local p1=$((15000 + RANDOM % 30000))
        local p2=$((15000 + RANDOM % 30000))
        local p3=$((15000 + RANDOM % 30000))
        local p4=$((15000 + RANDOM % 30000))
        local p5=$((15000 + RANDOM % 30000))
        echo "$p1 $p2 $p3 $p4 $p5"
    fi
}

echo -e "${C_CYAN}Mengalokasikan port Docker acak/random (rentang 15000-49999)...${C_RESET}"
echo -e "${C_CYAN}Mengeliminasi port dari: docker ps, ss/netstat, kernel proc, dan .env proyek lain...${C_RESET}"
RANDOM_PORTS=($(get_random_ports))
APP_PORT="${RANDOM_PORTS[0]}"
VITE_PORT="${RANDOM_PORTS[1]}"
DB_PORT="${RANDOM_PORTS[2]}"
PMA_PORT="${RANDOM_PORTS[3]}"
REDIS_PORT="${RANDOM_PORTS[4]}"

echo -e "  • Web App (Nginx) : ${C_BOLD}$APP_PORT${C_RESET} (Random)"
echo -e "  • Vite Dev (HMR)  : ${C_BOLD}$VITE_PORT${C_RESET} (Random)"
echo -e "  • MySQL Database  : ${C_BOLD}$DB_PORT${C_RESET} (Random)"
echo -e "  • phpMyAdmin      : ${C_BOLD}$PMA_PORT${C_RESET} (Random)"
echo -e "  • Redis Cache     : ${C_BOLD}$REDIS_PORT${C_RESET} (Random)"

# Simpan marker port untuk eksekusi firewall di host OS
echo "$PROJECT_NAME $APP_PORT $VITE_PORT $DB_PORT $PMA_PORT $REDIS_PORT" > "$TARGET_DIR/.firewall_ports"

# Jalankan firewall helper jika running di host
if [ ! -f /.dockerenv ]; then
    if [ -x "$MACHINE_DIR/docker/firewall-helper.sh" ]; then
        "$MACHINE_DIR/docker/firewall-helper.sh" "$PROJECT_NAME" "$APP_PORT" "$VITE_PORT" "$DB_PORT" "$PMA_PORT" "$REDIS_PORT"
    fi
fi

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
echo -e "  ${C_BOLD}${C_GREEN}🎉 VEL ENGINE // SETUP DOCKER & MAKEFILE SIAP UNTUK: ${C_CYAN}$PROJECT_NAME${C_RESET}"
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
