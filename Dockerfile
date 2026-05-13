FROM debian:bookworm-slim

LABEL author="murillo" maintainer="murillofrazaocunha@gmail.com"

ARG PHP_VERSION
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        curl \
        wget \
        gnupg2 \
        ca-certificates \
        lsb-release \
        unzip \
        git \
    # --- Repositórios Oficiais ---
    # Nginx
    && curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nginx.gpg] https://nginx.org/packages/mainline/debian bookworm nginx" > /etc/apt/sources.list.d/nginx.list \
    # Caddy
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list \
    # PHP
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    # --- Instalação ---
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx apache2 caddy \
        php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-common \
        php${PHP_VERSION}-mysql php${PHP_VERSION}-pdo php${PHP_VERSION}-xml php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-calendar php${PHP_VERSION}-ctype php${PHP_VERSION}-curl php${PHP_VERSION}-dom \
        php${PHP_VERSION}-mbstring php${PHP_VERSION}-fileinfo php${PHP_VERSION}-ftp php${PHP_VERSION}-gd \
        php${PHP_VERSION}-gettext php${PHP_VERSION}-gmp php${PHP_VERSION}-iconv php${PHP_VERSION}-igbinary \
        php${PHP_VERSION}-imagick php${PHP_VERSION}-imap php${PHP_VERSION}-intl php${PHP_VERSION}-ldap \
        php${PHP_VERSION}-exif php${PHP_VERSION}-mongodb php${PHP_VERSION}-msgpack php${PHP_VERSION}-mysqli \
        php${PHP_VERSION}-odbc php${PHP_VERSION}-pcov php${PHP_VERSION}-pgsql php${PHP_VERSION}-phar \
        php${PHP_VERSION}-posix php${PHP_VERSION}-ps php${PHP_VERSION}-pspell php${PHP_VERSION}-readline \
        php${PHP_VERSION}-shmop php${PHP_VERSION}-simplexml php${PHP_VERSION}-soap php${PHP_VERSION}-sockets \
        php${PHP_VERSION}-sqlite3 php${PHP_VERSION}-sysvmsg php${PHP_VERSION}-sysvsem php${PHP_VERSION}-sysvshm \
        php${PHP_VERSION}-tokenizer php${PHP_VERSION}-xmlreader php${PHP_VERSION}-xmlwriter php${PHP_VERSION}-xsl \
        php${PHP_VERSION}-zip php${PHP_VERSION}-mailparse php${PHP_VERSION}-inotify php${PHP_VERSION}-maxminddb \
        php${PHP_VERSION}-protobuf php${PHP_VERSION}-opcache php${PHP_VERSION}-memcached \
    # --- Composer ---
    &&  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    # --- Limpeza de Camada (DEVE ser aqui para reduzir o tamanho real do upload) ---
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# --- Traefik (Multi-Arch) ---
RUN ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then TRAEFIK_ARCH="amd64"; \
    elif [ "$ARCH" = "aarch64" ]; then TRAEFIK_ARCH="arm64"; \
    else echo "Traefik: Unsupported arch - skipping"; exit 0; fi; \
    TRAEFIK_VERSION="v3.0.0"; \
    curl -sL "https://github.com/traefik/traefik/releases/download/${TRAEFIK_VERSION}/traefik_${TRAEFIK_VERSION}_linux_${TRAEFIK_ARCH}.tar.gz" -o /tmp/traefik.tar.gz \
    && tar xzf /tmp/traefik.tar.gz -C /usr/local/bin traefik \
    && chmod +x /usr/local/bin/traefik \
    && rm /tmp/traefik.tar.gz

# --- ionCube Loader (Multi-Arch) ---
RUN ARCH=$(uname -m); \
    if [ "$ARCH" = "x86_64" ]; then IONCUBE_ARCH="x86-64"; \
    elif [ "$ARCH" = "aarch64" ]; then IONCUBE_ARCH="aarch64"; \
    else echo "ionCube: Unsupported arch - skipping"; exit 0; fi; \
    cd /tmp && wget -q "https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_${IONCUBE_ARCH}.tar.gz" \
    && tar xzf ioncube_loaders_lin_${IONCUBE_ARCH}.tar.gz \
    && PHP_EXT_DIR=$(php -r "echo ini_get('extension_dir');") \
    && if [ -f "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" ]; then \
        cp "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" "$PHP_EXT_DIR/"; \
        echo "zend_extension=ioncube_loader_lin_${PHP_VERSION}.so" > /etc/php/${PHP_VERSION}/fpm/conf.d/00-ioncube.ini; \
        echo "zend_extension=ioncube_loader_lin_${PHP_VERSION}.so" > /etc/php/${PHP_VERSION}/cli/conf.d/00-ioncube.ini; \
    fi \
    && rm -rf /tmp/ioncube*

# User Setup
RUN useradd -m -d /home/container/ -s /bin/bash container

# USER container
# ENV USER=container HOME=/home/container
# WORKDIR /home/container

STOPSIGNAL SIGINT
