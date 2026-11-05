# ==============================================================================
# Dockerfile: Complete PHP 8.4 + Laravel Installer + Node.js Environment
# ==============================================================================
FROM php:8.4-fpm

# Arguments for host user synchronization (UID & GID)
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_HOME=/usr/local/composer
ENV PATH="/usr/local/composer/vendor/bin:/home/developer/.composer/vendor/bin:${PATH}"

# 1. Install system utilities, build dependencies, database clients
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    zip \
    unzip \
    nano \
    procps \
    ca-certificates \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libwebp-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    libsqlite3-dev \
    mariadb-client \
    sqlite3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Install Node.js 22 (LTS) & latest npm
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g npm@latest \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Configure and install core PHP extensions for Laravel
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        bcmath \
        exif \
        gd \
        intl \
        opcache \
        pcntl \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        zip

# 4. Install Redis extension via PECL
RUN pecl install redis \
    && docker-php-ext-enable redis

# 5. Install Composer latest
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 6. Install global Laravel Installer CLI & Scaffolder Wrapper
RUN mkdir -p /usr/local/composer /usr/local/share/laravel-docker-machine \
    && COMPOSER_HOME=/usr/local/composer composer global require laravel/installer \
    && chmod -R 777 /usr/local/composer

COPY templates /usr/local/share/laravel-docker-machine/templates
COPY docker/scaffold-project.sh /usr/local/share/laravel-docker-machine/docker/scaffold-project.sh
COPY docker/laravel-wrapper.sh /usr/local/bin/laravel
RUN chmod +x /usr/local/share/laravel-docker-machine/docker/scaffold-project.sh /usr/local/bin/laravel

# 7. Create developer non-root user matching host UID/GID
RUN groupadd -g ${GID} developer 2>/dev/null || true \
    && useradd -u ${UID} -g ${GID} -m -s /bin/bash developer 2>/dev/null || true \
    && usermod -aG www-data developer 2>/dev/null || true \
    && mkdir -p /home/developer/.composer /var/www/html \
    && chown -R ${UID}:${GID} /home/developer /var/www/html

# 8. Configure git safe directory
RUN git config --system --add safe.directory /var/www/html \
    && git config --system --add safe.directory '*'

WORKDIR /var/www/html

# Copy custom configurations
COPY docker/php/php.ini /usr/local/etc/php/conf.d/custom-php.ini
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 9000 8000 5173

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
