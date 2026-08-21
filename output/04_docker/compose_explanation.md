<div dir="rtl">

# راهنمای Docker Compose و قالب‌های پیکربندی Vikunja

این مستند ساختار و عملکرد فایل‌های Docker Compose و قالب‌های Jinja2 مورد استفاده برای استقرار **Vikunja** را توضیح می‌دهد. این استقرار شامل سه سرویس اصلی است:

- **Vikunja** برای مدیریت وظایف
- **PostgreSQL** به‌عنوان پایگاه داده
- **Nginx** به‌عنوان پروکسی معکوس و نقطه ورود امن

تمام پیکربندی‌ها در قالب نقش‌های Ansible طراحی شده‌اند تا فرایند نصب، تنظیم و نگهداری سرویس‌ها به‌صورت خودکار، تکرارپذیر و قابل مدیریت انجام شود.

---

## ۱. نمای کلی معماری

معماری این استقرار از سه کانتینر Docker تشکیل شده است:

| سرویس | وظیفه |
|---|---|
| **Vikunja** | اجرای برنامه مدیریت وظایف |
| **PostgreSQL** | ذخیره‌سازی داده‌ها، کاربران، پروژه‌ها و وظایف |
| **Nginx** | دریافت درخواست‌های HTTP و HTTPS، مدیریت TLS و ارسال درخواست‌ها به Vikunja |

تمام سرویس‌ها در یک شبکه Docker مشترک با نام `vikunja_net` قرار می‌گیرند. این شبکه باعث می‌شود سرویس‌ها بتوانند با نام سرویس یکدیگر را پیدا کنند و بدون نیاز به باز کردن پورت‌های غیرضروری روی میزبان، با هم ارتباط داشته باشند.

مسیر کلی ترافیک به شکل زیر است:

```text
کاربر
  ↓
Nginx روی پورت‌های 80 و 443
  ↓
Vikunja
  ↓
PostgreSQL
```

---

## ۲. فایل `docker-compose.yml`

این فایل مسئول اجرای سرویس‌های **Vikunja** و **PostgreSQL** است.

```yaml
services:
  vikunja:
    image: vikunja/vikunja:2.5.0
    environment:
      VIKUNJA_SERVICE_PUBLICURL: ${VIKUNJA_SERVICE_PUBLICURL}
      VIKUNJA_SERVICE_SECRET: ${VIKUNJA_SERVICE_SECRET}
      VIKUNJA_DATABASE_HOST: ${VIKUNJA_DATABASE_HOST}
      VIKUNJA_DATABASE_PASSWORD: ${VIKUNJA_DATABASE_PASSWORD}
      VIKUNJA_DATABASE_TYPE: postgres
      VIKUNJA_DATABASE_USER: ${VIKUNJA_DATABASE_USER}
      VIKUNJA_DATABASE_DATABASE: ${VIKUNJA_DATABASE_DATABASE}
    ports:
      - 127.0.0.1:${APP_INTERNAL_PORT}:3456
    volumes:
      - ./files:/app/vikunja/files
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - vikunja_net

  db:
    image: postgres:18
    environment:
      POSTGRES_PASSWORD: ${VIKUNJA_DATABASE_PASSWORD}
      POSTGRES_USER: ${VIKUNJA_DATABASE_USER}
      POSTGRES_DB: ${VIKUNJA_DATABASE_DATABASE}
    volumes:
      - ./db:/var/lib/postgresql
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -h localhost -U $$POSTGRES_USER"]
      interval: 2s
      start_period: 30s
    networks:
      - vikunja_net

networks:
  vikunja_net:
    name: ${DOCKER_NETWORK_NAME}
    external: true
```

### سرویس `vikunja`

این سرویس برنامه Vikunja را اجرا می‌کند.

- از تصویر رسمی `vikunja/vikunja:2.5.0` استفاده می‌شود.
- تمامی اطلاعات پیکربندی از فایل `.env` دریافت می‌شوند.
- فایل `.env` توسط قالب `env.j2` و با استفاده از متغیرهای Ansible تولید می‌شود.

متغیرهای مهم این سرویس عبارت‌اند از:

| متغیر | کاربرد |
|---|---|
| `VIKUNJA_SERVICE_PUBLICURL` | آدرس عمومی Vikunja، همراه با پروتکل HTTPS |
| `VIKUNJA_SERVICE_SECRET` | کلید محرمانه مورد نیاز برای امضای توکن‌ها و عملیات رمزنگاری |
| `VIKUNJA_DATABASE_HOST` | نام میزبان پایگاه داده؛ معمولاً `db` |
| `VIKUNJA_DATABASE_USER` | نام کاربر پایگاه داده |
| `VIKUNJA_DATABASE_PASSWORD` | رمز عبور پایگاه داده |
| `VIKUNJA_DATABASE_DATABASE` | نام پایگاه داده |
| `VIKUNJA_DATABASE_TYPE` | نوع پایگاه داده که در اینجا `postgres` است |

#### نگاشت پورت

```yaml
ports:
  - 127.0.0.1:${APP_INTERNAL_PORT}:3456
```

Vikunja درون کانتینر روی پورت `3456` اجرا می‌شود، اما این پورت فقط روی آدرس `127.0.0.1` میزبان منتشر می‌گردد.

این تنظیم باعث می‌شود سرویس Vikunja مستقیماً از اینترنت قابل دسترسی نباشد و تمام ترافیک خارجی فقط از طریق Nginx عبور کند.

#### ذخیره‌سازی فایل‌ها

```yaml
volumes:
  - ./files:/app/vikunja/files
```

دایرکتوری `./files` روی میزبان به مسیر `/app/vikunja/files` در کانتینر متصل می‌شود. فایل‌های پیوست کاربران در این مسیر نگهداری شده و با حذف یا بازسازی کانتینر از بین نمی‌روند.

#### وابستگی به پایگاه داده

```yaml
depends_on:
  db:
    condition: service_healthy
```

سرویس Vikunja تا زمانی که PostgreSQL سالم و آماده دریافت اتصال نباشد، شروع به کار نمی‌کند.

#### راه‌اندازی مجدد

```yaml
restart: unless-stopped
```

کانتینر در صورت توقف غیرمنتظره یا راه‌اندازی مجدد Docker دوباره اجرا می‌شود؛ مگر این‌که مدیر سیستم آن را به‌صورت دستی متوقف کرده باشد.

---

### سرویس `db`

این سرویس پایگاه داده PostgreSQL را اجرا می‌کند.

```yaml
image: postgres:18
```

اطلاعات لازم برای ایجاد اولیه پایگاه داده از متغیرهای محیطی دریافت می‌شوند:

```yaml
environment:
  POSTGRES_PASSWORD: ${VIKUNJA_DATABASE_PASSWORD}
  POSTGRES_USER: ${VIKUNJA_DATABASE_USER}
  POSTGRES_DB: ${VIKUNJA_DATABASE_DATABASE}
```

#### ذخیره‌سازی دائمی داده‌ها

```yaml
volumes:
  - ./db:/var/lib/postgresql
```

داده‌های PostgreSQL در دایرکتوری `./db` روی میزبان ذخیره می‌شوند تا با حذف کانتینر از بین نروند.

#### بررسی سلامت پایگاه داده

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -h localhost -U $$POSTGRES_USER"]
  interval: 2s
  start_period: 30s
```

دستور `pg_isready` هر دو ثانیه وضعیت PostgreSQL را بررسی می‌کند. زمان `start_period` نیز به پایگاه داده فرصت می‌دهد تا در شروع اولیه کاملاً آماده شود.

---

### شبکه Docker

```yaml
networks:
  vikunja_net:
    name: ${DOCKER_NETWORK_NAME}
    external: true
```

شبکه `vikunja_net` به‌صورت خارجی تعریف شده است؛ یعنی Docker Compose آن را ایجاد نمی‌کند و باید پیش از اجرای سرویس‌ها وجود داشته باشد.

این شبکه معمولاً توسط نقش Ansible مربوط به شبکه ایجاد می‌شود. در صورت نیاز می‌توان آن را به‌صورت دستی نیز ایجاد کرد:

```bash
docker network create vikunja_net
```

---

## ۳. فایل `docker-compose-nginx.yml`

این فایل سرویس Nginx را اجرا می‌کند.

```yaml
services:
  nginx:
    image: ${NGINX_IMAGE}
    container_name: ${NGINX_CONTAINER_NAME}
    ports:
      - "${NGINX_HTTP_PORT}:80"
      - "${NGINX_HTTPS_PORT}:443"
    volumes:
      - ./nginx_config.txt:/etc/nginx/conf.d/default.conf:ro
      - ${NGINX_SSL_HOST_DIR}:/etc/nginx/ssl:ro
    restart: unless-stopped
    networks:
      - vikunja_net

networks:
  vikunja_net:
    name: ${DOCKER_NETWORK_NAME}
    external: true
```

### سرویس `nginx`

Nginx به‌عنوان پروکسی معکوس عمل می‌کند و تنها سرویس در معرض اینترنت است.

| بخش | توضیح |
|---|---|
| `NGINX_IMAGE` | تصویر Docker مربوط به Nginx |
| `NGINX_CONTAINER_NAME` | نام کانتینر Nginx |
| `NGINX_HTTP_PORT` | پورت HTTP روی میزبان، معمولاً `80` |
| `NGINX_HTTPS_PORT` | پورت HTTPS روی میزبان، معمولاً `443` |
| `NGINX_SSL_HOST_DIR` | مسیر گواهی و کلید TLS روی میزبان |

### نگاشت پورت‌ها

```yaml
ports:
  - "${NGINX_HTTP_PORT}:80"
  - "${NGINX_HTTPS_PORT}:443"
```

Nginx درخواست‌های HTTP و HTTPS را از بیرون دریافت می‌کند:

- پورت `80` برای هدایت خودکار کاربران به HTTPS
- پورت `443` برای ارائه نسخه رمزنگاری‌شده برنامه

### اتصال فایل‌های پیکربندی

```yaml
volumes:
  - ./nginx_config.txt:/etc/nginx/conf.d/default.conf:ro
  - ${NGINX_SSL_HOST_DIR}:/etc/nginx/ssl:ro
```

فایل تنظیمات Nginx و گواهی‌های TLS به‌صورت فقط‌خواندنی در اختیار کانتینر قرار می‌گیرند.

استفاده از حالت `ro` باعث می‌شود کانتینر نتواند فایل پیکربندی یا گواهی‌ها را تغییر دهد.

---

## ۴. قالب‌های Jinja2

### الف) قالب `.env.j2` برای Vikunja

این قالب در نقش `app_setup` استفاده می‌شود و فایل `.env` مربوط به سرویس Vikunja را تولید می‌کند.

```jinja
mirrer_setting=""
# mirrer_setting=[Parspack,SHATEL,GOVERNMENT,ARVANCLOUD]

APP_URL_PUBLIC={{ vikunja_url_public }}
VIKUNJA_SERVICE_PUBLICURL=https://{{ vikunja_url_public }}/
VIKUNJA_SERVICE_SECRET={{ vikunja_service_secret }}
VIKUNJA_DATABASE_HOST={{ vikunja_database_host }}
VIKUNJA_DATABASE_PASSWORD={{ vikunja_database_password }}
VIKUNJA_DATABASE_USER={{ vikunja_database_user }}
VIKUNJA_DATABASE_DATABASE={{ vikunja_database_name }}
APP_INTERNAL_PORT={{ app_internal_port }}
DOCKER_NETWORK_NAME={{ docker_network_name }}
```

این فایل بر اساس متغیرهای تعریف‌شده در `webserver.yml` تولید می‌شود و در کنار `docker-compose.yml` قرار می‌گیرد.

### متغیرهای مهم

| متغیر | توضیح |
|---|---|
| `APP_URL_PUBLIC` | آدرس عمومی برنامه |
| `VIKUNJA_SERVICE_PUBLICURL` | آدرس کامل Vikunja همراه با `https://` |
| `VIKUNJA_SERVICE_SECRET` | کلید محرمانه سرویس |
| `VIKUNJA_DATABASE_HOST` | آدرس یا نام سرویس پایگاه داده |
| `APP_INTERNAL_PORT` | پورت داخلی منتشرشده روی میزبان |
| `DOCKER_NETWORK_NAME` | نام شبکه Docker مشترک |

متغیر `mirrer_setting` برای تنظیمات خاص یا محیط‌های دارای محدودیت دریافت تصاویر Docker در نظر گرفته شده است و در صورت عدم نیاز می‌تواند خالی باقی بماند.

---

### ب) قالب `.env.j2` برای Nginx

این قالب در نقش `network` استفاده می‌شود.

```jinja
DOCKER_NETWORK_NAME={{ docker_network_name }}
NGINX_IMAGE={{ nginx_image }}
NGINX_CONTAINER_NAME={{ nginx_container_name }}
NGINX_HTTP_PORT={{ nginx_http_port }}
NGINX_HTTPS_PORT={{ nginx_https_port }}
NGINX_SSL_HOST_DIR={{ nginx_ssl_host_dir }}
```

فایل خروجی معمولاً در مسیر مربوط به Nginx، مانند `/opt/nginx/.env`، قرار می‌گیرد تا Docker Compose بتواند متغیرهای مورد نیاز را بارگذاری کند.

---

### ج) قالب `nginx_config.txt.j2`

این قالب، فایل پیکربندی اصلی Nginx را تولید می‌کند.

```jinja
# Nginx reverse proxy for Vikunja.
# The certificate and key are generated/provisioned on the host and mounted
# read-only into the container at {{ nginx_ssl_container_dir }}.

server {
    listen 80;
    listen [::]:80;
    server_name {{ nginx_server_name }};

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name {{ nginx_server_name }};

    client_max_body_size 20M;

    ssl_certificate     {{ nginx_ssl_container_dir }}/{{ nginx_ssl_certificate }};
    ssl_certificate_key {{ nginx_ssl_container_dir }}/{{ nginx_ssl_certificate_key }};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5:!3DES;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        proxy_pass http://{{ nginx_upstream_host }}:{{ nginx_upstream_port }};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    error_page 502 503 504 /50x.html;

    location = /50x.html {
        root /usr/share/nginx/html;
    }

    access_log /var/log/nginx/vikunja_access.log;
    error_log /var/log/nginx/vikunja_error.log;
}
```

### بخش HTTP

```nginx
server {
    listen 80;
    listen [::]:80;

    return 301 https://$host$request_uri;
}
```

تمام درخواست‌های HTTP به نسخه HTTPS همان آدرس هدایت می‌شوند. این کار مانع انتقال اطلاعات کاربران به‌صورت رمزنگاری‌نشده می‌شود.

### بخش HTTPS

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;
}
```

این بخش درخواست‌های امن HTTPS را دریافت می‌کند و با استفاده از گواهی و کلید خصوصی TLS، ارتباط رمزنگاری‌شده را برقرار می‌سازد.

### محدودیت حجم آپلود

```nginx
client_max_body_size 20M;
```

حداکثر اندازه فایل ارسالی کاربران به `20MB` محدود شده است. در صورت نیاز به بارگذاری فایل‌های بزرگ‌تر، این مقدار باید متناسب با نیاز سامانه افزایش یابد.

### ارسال درخواست به Vikunja

```nginx
location / {
    proxy_pass http://{{ nginx_upstream_host }}:{{ nginx_upstream_port }};
}
```

تمام درخواست‌ها به سرویس Vikunja ارسال می‌شوند. مقدار `nginx_upstream_host` معمولاً `vikunja` است که با نام سرویس Vikunja در فایل Compose مطابقت دارد.

### هدرهای پروکسی

هدرهای زیر اطلاعات اصلی درخواست را به Vikunja منتقل می‌کنند:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

این تنظیمات باعث می‌شوند برنامه بتواند نام دامنه، IP واقعی کاربر و پروتکل اصلی اتصال را تشخیص دهد.

---

## ۵. نحوه ارتباط سرویس‌ها

### ارتباط Nginx با Vikunja

Nginx از طریق شبکه داخلی Docker به سرویس Vikunja متصل می‌شود:

```nginx
proxy_pass http://vikunja:3456;
```

در این حالت، Docker نام سرویس `vikunja` را به آدرس داخلی کانتینر مربوطه تبدیل می‌کند.

### ارتباط Vikunja با PostgreSQL

Vikunja نیز برای اتصال به پایگاه داده از نام سرویس `db` استفاده می‌کند:

```text
VIKUNJA_DATABASE_HOST=db
```

این ارتباط کاملاً درون شبکه Docker انجام می‌شود و نیازی به باز کردن پورت PostgreSQL روی میزبان ندارد.

### دسترسی خارجی

تنها Nginx پورت‌های زیر را روی میزبان منتشر می‌کند:

| پورت | کاربرد |
|---|---|
| `80` | هدایت HTTP به HTTPS |
| `443` | دسترسی امن کاربران به Vikunja |

سرویس Vikunja فقط روی `127.0.0.1` در دسترس است و PostgreSQL نیز هیچ پورتی به بیرون منتشر نمی‌کند. این طراحی سطح حمله سرویس‌ها را کاهش می‌دهد.

---

## ۶. نکات امنیتی و عملیاتی

### حفاظت از اطلاعات حساس

مقادیر حساس زیر باید با دقت نگهداری شوند:

- `VIKUNJA_SERVICE_SECRET`
- `VIKUNJA_DATABASE_PASSWORD`
- کلید خصوصی TLS

پیشنهاد می‌شود فایل‌های `.env` دارای سطح دسترسی `0600` باشند:

```bash
chmod 600 .env
```

همچنین در وظایف Ansible که با اطلاعات محرمانه کار می‌کنند، بهتر است از گزینه زیر استفاده شود:

```yaml
no_log: true
```

### مجوز فایل‌های گواهی

پیشنهاد می‌شود مجوز فایل‌های TLS به شکل زیر تنظیم شود:

```bash
chmod 600 private.key
chmod 644 certificate.crt
```

### بررسی سلامت PostgreSQL

استفاده از `healthcheck` مانع از اجرای زودهنگام Vikunja می‌شود و احتمال خطاهای اتصال اولیه به پایگاه داده را کاهش می‌دهد.

### پشتیبان‌گیری

پوشه‌های زیر شامل داده‌های پایدار سامانه هستند و باید به‌صورت منظم پشتیبان‌گیری شوند:

```text
./db
./files
```

نمونه پشتیبان‌گیری از پایگاه داده:

```bash
docker compose exec db pg_dump -U "$VIKUNJA_DATABASE_USER" "$VIKUNJA_DATABASE_DATABASE" > vikunja_backup.sql
```

---

## ۷. جمع‌بندی

این ساختار یک استقرار امن، ماژولار و قابل نگهداری برای Vikunja فراهم می‌کند.

ویژگی‌های اصلی این معماری:

- اجرای مستقل Vikunja، PostgreSQL و Nginx در کانتینرهای جداگانه
- ارتباط داخلی سرویس‌ها از طریق شبکه Docker اختصاصی
- عدم انتشار مستقیم پورت PostgreSQL
- محدود شدن دسترسی مستقیم به Vikunja
- ارائه سرویس تنها از طریق Nginx و HTTPS
- مدیریت متغیرها و پیکربندی‌ها با Ansible و Jinja2
- امکان استفاده از یک پیکربندی واحد در محیط‌های توسعه، آزمایش و تولید

این طراحی، مدیریت زیرساخت را ساده‌تر کرده و با جداسازی مسئولیت سرویس‌ها، امنیت و قابلیت اطمینان سامانه را افزایش می‌دهد.

</div>