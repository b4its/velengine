#!/usr/bin/env bash
# ==============================================================================
# Vel Engine - Container Laravel CLI Wrapper
# Intercepts 'laravel new' to automatically save to projects/ and scaffold Docker & Makefile
# ==============================================================================
REAL_LARAVEL="/usr/local/composer/vendor/laravel/installer/bin/laravel"

# Pass through non-'new' commands directly
if [ "$1" != "new" ]; then
    exec "$REAL_LARAVEL" "$@"
fi

# Detect project name / target argument if provided
TARGET_ARG=""
for arg in "${@:2}"; do
    if [[ ! "$arg" =~ ^- ]]; then
        TARGET_ARG="$arg"
        break
    fi
done

# If target is not '.' (root), ensure we create inside /var/www/html/projects
CURRENT_DIR="$(pwd)"
if [ "$TARGET_ARG" != "." ]; then
    if [ "$CURRENT_DIR" = "/var/www/html" ]; then
        mkdir -p /var/www/html/projects
        cd /var/www/html/projects
    fi
    if [ -n "$TARGET_ARG" ]; then
        CLEAN_TARGET="${TARGET_ARG#projects/}"
        ARGS=()
        for a in "$@"; do
            if [ "$a" = "$TARGET_ARG" ]; then
                ARGS+=("$CLEAN_TARGET")
            else
                ARGS+=("$a")
            fi
        done
        set -- "${ARGS[@]}"
        TARGET_ARG="$CLEAN_TARGET"
    fi
fi

BEFORE_DIRS=""
if [ -z "$TARGET_ARG" ]; then
    BEFORE_DIRS=$(find . -maxdepth 1 -type d 2>/dev/null | sort)
fi

# Run the real Laravel installer
"$REAL_LARAVEL" "$@"
EXIT_CODE=$?

# If command succeeded, scaffold Docker & Makefile
if [ $EXIT_CODE -eq 0 ]; then
    if [ -z "$TARGET_ARG" ]; then
        AFTER_DIRS=$(find . -maxdepth 1 -type d 2>/dev/null | sort)
        TARGET_ARG=$(comm -13 <(echo "$BEFORE_DIRS") <(echo "$AFTER_DIRS") | head -n1 | sed 's|^\./||')
    fi
    [ -z "$TARGET_ARG" ] && TARGET_ARG="."

    SCAFFOLD_SCRIPT=""
    if [ -x "/var/www/html/docker/scaffold-project.sh" ]; then
        SCAFFOLD_SCRIPT="/var/www/html/docker/scaffold-project.sh"
    elif [ -x "/usr/local/share/laravel-docker-machine/docker/scaffold-project.sh" ]; then
        SCAFFOLD_SCRIPT="/usr/local/share/laravel-docker-machine/docker/scaffold-project.sh"
    fi

    if [ -n "$SCAFFOLD_SCRIPT" ]; then
        "$SCAFFOLD_SCRIPT" "$TARGET_ARG"
    fi
fi

exit $EXIT_CODE
