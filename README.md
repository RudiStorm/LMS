# Chamilo LMS on Coolify

This repository contains a Coolify-ready Docker Compose deployment for Chamilo LMS.

It is intended for a corporate LMS deployment and explicitly does **not** use Moodle or Open edX.

## Goal

Use this repo to deploy:

- Chamilo LMS 2.x
- PHP 8.3 with Apache
- MariaDB 10.11
- Persistent storage for uploads, runtime files, configuration, and database data
- Coolify-managed environment variables and generated secrets

## Important requirements

Chamilo 2.x should run on PHP 8.2 or PHP 8.3 and requires Composer, Node.js/Yarn or npm, and a supported database such as MariaDB 10.11.

Coolify Docker Compose deployments should treat `docker-compose.yml` as the source of truth. Any runtime environment variable that must be configurable in Coolify should be declared in the compose file.

## Repository structure

```txt
.
├── Dockerfile
├── docker-compose.yml
├── apache-chamilo.conf
├── php.ini
└── README.md
```

## docker-compose.yml

```yaml
services:
  chamilo:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        CHAMILO_VERSION: ${CHAMILO_VERSION:-2.0}
    environment:
      APP_ENV: prod
      APP_SECRET: ${SERVICE_BASE64_64_APPSECRET}
      DATABASE_URL: mysql://chamilo:${SERVICE_PASSWORD_DB}@mariadb:3306/chamilo?serverVersion=mariadb-10.11
      MAILER_DSN: ${MAILER_DSN:-null://null}
      PHP_MEMORY_LIMIT: ${PHP_MEMORY_LIMIT:-512M}
      PHP_UPLOAD_MAX_FILESIZE: ${PHP_UPLOAD_MAX_FILESIZE:-500M}
      PHP_POST_MAX_SIZE: ${PHP_POST_MAX_SIZE:-500M}
      PHP_MAX_EXECUTION_TIME: ${PHP_MAX_EXECUTION_TIME:-300}
    volumes:
      - chamilo_var:/var/www/html/var
      - chamilo_upload:/var/www/html/public/upload
      - chamilo_config:/var/www/html/config
    depends_on:
      mariadb:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://localhost/ || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

  mariadb:
    image: mariadb:10.11
    environment:
      MARIADB_DATABASE: chamilo
      MARIADB_USER: chamilo
      MARIADB_PASSWORD: ${SERVICE_PASSWORD_DB}
      MARIADB_ROOT_PASSWORD: ${SERVICE_PASSWORD_DB_ROOT}
    volumes:
      - mariadb_data:/var/lib/mysql
    healthcheck:
      test: ["CMD-SHELL", "mariadb-admin ping -h localhost -u root -p$${MARIADB_ROOT_PASSWORD} --silent"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

volumes:
  mariadb_data:
  chamilo_var:
  chamilo_upload:
  chamilo_config:
```

## Dockerfile

```dockerfile
FROM php:8.3-apache

ARG CHAMILO_VERSION=2.0

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
    libbz2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure ldap \
    && docker-php-ext-install \
        intl \
        gd \
        zip \
        pdo \
        pdo_mysql \
        mbstring \
        opcache \
        curl \
        xml \
        ldap \
        exif \
        bcmath \
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

RUN composer install --no-dev --optimize-autoloader --no-interaction

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
```

## apache-chamilo.conf

```apache
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/public

    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted
        Options FollowSymLinks
    </Directory>

    <Directory /var/www/html>
        AllowOverride None
        Require all denied
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/chamilo_error.log
    CustomLog ${APACHE_LOG_DIR}/chamilo_access.log combined
</VirtualHost>
```

## php.ini

```ini
memory_limit = 512M
upload_max_filesize = 500M
post_max_size = 500M
max_execution_time = 300
max_input_vars = 10000
date.timezone = Africa/Johannesburg

opcache.enable = 1
opcache.memory_consumption = 256
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0
```

## Coolify deployment steps

1. Push this repository to GitHub, GitLab, or another Git provider connected to Coolify.
2. In Coolify, create or select a project.
3. Add a new resource.
4. Choose Docker Compose from Git repository.
5. Select this repository.
6. Assign the public domain to the `chamilo` service.
7. Set the domain to something like:

```txt
https://lms.example.com
```

8. Deploy the application.

## Coolify environment variables

Coolify should detect the variables referenced in `docker-compose.yml`.

Set or verify these variables in Coolify:

```env
CHAMILO_VERSION=2.0
MAILER_DSN=null://null
PHP_MEMORY_LIMIT=512M
PHP_UPLOAD_MAX_FILESIZE=500M
PHP_POST_MAX_SIZE=500M
PHP_MAX_EXECUTION_TIME=300
```

Coolify should generate these automatically because they use Coolify magic variable syntax:

```env
SERVICE_BASE64_64_APPSECRET
SERVICE_PASSWORD_DB
SERVICE_PASSWORD_DB_ROOT
```

For production email, replace `MAILER_DSN=null://null` with a real SMTP DSN:

```env
MAILER_DSN=smtp://username:password@smtp.example.com:587
```

When setting SMTP credentials in Coolify, mark sensitive values as secrets where possible.

## First-run installer

After the first successful deployment, open the configured domain in a browser.

Chamilo should display the web-based installer.

Use the following database settings:

```txt
Database host: mariadb
Database port: 3306
Database name: chamilo
Database user: chamilo
Database password: value of SERVICE_PASSWORD_DB from Coolify
```

Create the first administrator user during the Chamilo installer flow.

## Post-install checks

After installation, log in as the administrator and check:

```txt
Administration -> System status
```

Confirm that:

- Required PHP extensions are available.
- Required directories are writable.
- Upload limits are correct.
- Database connectivity is healthy.
- Disk space is sufficient.

## Recommended production settings

Inside Chamilo administration, configure the following:

```txt
Administration -> Configuration settings -> Security
```

Recommended values:

```txt
Force HTTPS: enabled
Self-registration: disabled unless required
Public course catalogue: disabled unless required
CAPTCHA or brute-force protection: enabled where available
```

## Persistent volumes

This deployment creates four Docker volumes:

```txt
mariadb_data
chamilo_var
chamilo_upload
chamilo_config
```

Back up all four volumes.

The most important data is:

```txt
mariadb_data      # users, courses, learning records, platform settings
chamilo_upload    # course files, SCORM packages, documents, media
chamilo_config    # generated/local configuration
chamilo_var       # runtime files, cache, logs, generated files
```

## Backup recommendation

Before onboarding users, configure backups in Coolify for:

- MariaDB database volume
- Chamilo uploads volume
- Chamilo configuration volume

For corporate deployments, use daily backups at minimum and test restore procedures before go-live.

## Local smoke test

Optional local test:

```bash
docker compose up --build
```

Then open:

```txt
http://localhost
```

If port 80 is already in use locally, temporarily add a port mapping to the `chamilo` service:

```yaml
ports:
  - "8080:80"
```

Then open:

```txt
http://localhost:8080
```

Do not keep the explicit `ports` mapping for Coolify unless you specifically need it. Coolify normally handles routing through the assigned service domain.

## Troubleshooting

### Installer cannot connect to the database

Check that the database host is exactly:

```txt
mariadb
```

Check that the password matches `SERVICE_PASSWORD_DB` in Coolify.

### 500 error after install

Check container logs in Coolify.

Common causes:

- Missing PHP extension
- Incorrect file permissions
- Failed Composer install
- Failed frontend asset build
- Bad generated config

### Permission errors

Enter the container shell and run:

```bash
chown -R www-data:www-data /var/www/html/var /var/www/html/public/upload /var/www/html/config
chmod -R ug+rwX /var/www/html/var /var/www/html/public/upload /var/www/html/config
```

### Cache issues

Run:

```bash
php bin/console cache:clear --env=prod
```

Do not delete the live cache directory manually while the app is running.

### Uploads fail

Verify:

- `upload_max_filesize`
- `post_max_size`
- Coolify proxy limits, if configured
- Available disk space
- Permissions on `public/upload`

## Security notes

- Use HTTPS only.
- Disable public registration unless the company explicitly needs it.
- Use a real SMTP provider for password resets and notifications.
- Keep Chamilo updated.
- Keep the Docker base image updated.
- Back up before upgrading.
- Test upgrades in staging before production.

## Codex implementation checklist

Codex should perform the following tasks:

1. Create the repository files listed above.
2. Ensure the compose file defines the `chamilo` and `mariadb` services.
3. Ensure all configurable runtime variables are present in `docker-compose.yml`.
4. Ensure the Apache document root is `/var/www/html/public`.
5. Ensure persistent volumes are declared for database, upload, config, and runtime data.
6. Ensure MariaDB uses version `10.11`.
7. Ensure PHP uses version `8.3`.
8. Ensure required PHP extensions are installed.
9. Ensure Composer dependencies are installed during the image build.
10. Ensure frontend dependencies are built if `package.json` is present.
11. Do not use Moodle.
12. Do not use Open edX.
13. Do not use the old `chamilo/docker-chamilo` image.
14. Do not commit real passwords, SMTP credentials, or generated secrets.
15. Keep this deployment compatible with Coolify Docker Compose deployments.

## Upgrade notes

To upgrade Chamilo later:

1. Back up all volumes.
2. Change `CHAMILO_VERSION` in Coolify.
3. Deploy to a staging resource first.
4. Run the Chamilo upgrade procedure if required by the release notes.
5. Verify login, courses, uploads, certificates, and tracking data.
6. Deploy to production only after validation.

## Suggested production architecture

For a small to medium corporate LMS:

```txt
Coolify app:
  chamilo service
  mariadb service

Persistent storage:
  mariadb_data
  chamilo_upload
  chamilo_config
  chamilo_var

External services:
  SMTP provider
  DNS provider
  HTTPS via Coolify proxy
  Off-server backups
```

## License note

Chamilo is open-source software. Review Chamilo's license and any third-party dependencies before deploying for a corporate client.
