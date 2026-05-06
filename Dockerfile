FROM php:8.3-apache

ARG CHAMILO_VERSION=2.0.0

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    ca-certificates \
    gnupg \
    default-mysql-client \
    libicu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libxml2-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libldap2-dev \
    libsodium-dev \
    libxslt1-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure ldap \
    && docker-php-ext-install -j$(nproc) \
        intl \
        gd \
        zip \
        pdo \
        pdo_mysql \
        mbstring \
        opcache \
        curl \
        bcmath \
        exif \
        ldap \
        soap \
        xml \
    && a2enmod rewrite headers env dir mime expires \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && corepack enable \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

RUN curl -L "https://github.com/chamilo/chamilo-lms/archive/refs/tags/v${CHAMILO_VERSION}.tar.gz" \
    | tar xz --strip-components=1

RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --no-progress \
    -vvv

RUN if [ -f package.json ]; then \
      yarn install --immutable || yarn install; \
      yarn build || npm run build; \
    fi

COPY apache-chamilo.conf /etc/apache2/sites-available/000-default.conf
COPY php.ini /usr/local/etc/php/conf.d/chamilo.ini

RUN mkdir -p var public/upload config \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R ug+rwX var public/upload config

EXPOSE 80

CMD ["apache2-foreground"]
