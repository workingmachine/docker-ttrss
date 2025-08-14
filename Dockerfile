FROM php:8.3-apache

RUN set -ex; \
    \
    apt-get update -y -q; \
    apt-get install -y -q --no-install-recommends \
        apt-utils \
        git \
        supervisor \
    ; \
    rm -rf /var/lib/apt/lists/*

# install PHP extensions
RUN set -ex; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update -y -q; \
    apt-get install -y -q --no-install-recommends \
        libfreetype6-dev \
        libjpeg-dev \
        libpng-dev \
        libwebp-dev \
        libxml2-dev \
        libpq-dev \
        libicu-dev \
    ; \
    \
    rm -rf /var/lib/apt/lists/*; \
    \
    docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    ; \
    \
    docker-php-ext-install -j "$(nproc)" \
        gd \
        intl \
        opcache \
        pcntl \
        mysqli \
        pdo_pgsql \
    ; \
    \
    # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
        | sort -u \
        | xargs -r dpkg-query --search \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual \
    ; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings

# use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# set php symbolic link
RUN ln -s /usr/local/bin/php /usr/bin/php

# enable apache modules and configuration
RUN set -ex; \
    \
    a2enmod remoteip; \
    touch /etc/apache2/conf-available/remoteip.conf; \
    a2enconf remoteip; \
    \
    a2enmod headers; \
    touch /etc/apache2/conf-available/headers.conf; \
    a2enconf headers; \
    \
    touch /etc/apache2/conf-available/securing-objects.conf; \
    a2enconf securing-objects

# set timezone
ENV TZ=Europe/Vienna
RUN set -ex; \
    ln --symbolic --no-dereference --force /usr/share/zoneinfo/$TZ /etc/localtime; \
    echo $TZ > /etc/timezone

# supervisord configuration
RUN set -ex; \
    mkdir --parents /var/log/supervisord /var/run/supervisord

COPY supervisord.conf /

# ttrss feed update daemon script
#COPY feed-update.sh /feed-update.sh
#RUN set -ex; \
#    \
#    chown www-data:www-data /feed-update.sh; \
#    chmod 744 /feed-update.sh

# create user foo
RUN set -ex; \
    useradd --no-create-home --shell /usr/sbin/nologin --uid 8004 foo; \
    usermod --home /nonexistent foo

# Avoid permission error later. This is likely suboptimal but it seems to work.
# The error is: PermissionError: [Errno 13] Permission denied: '/var/log/supervisord/supervisord.log'
RUN set -ex; \
    chown --recursive 8004:8004 /var/log/supervisord /var/run/supervisord

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]
