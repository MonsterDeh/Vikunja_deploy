# استقرار Vikunja با Ansible، Docker و Nginx

این پروژه برای آماده‌سازی یک سرور Ubuntu/Debian و اجرای Vikunja با Docker Compose
استفاده می‌شود. برنامه‌ی Vikunja و PostgreSQL در role `app_setup` اجرا می‌شوند و
role `network` یک شبکه‌ی داخلی Docker و یک Nginx reverse proxy با HTTPS ایجاد می‌کند.

## ساختار فایل‌های اصلی

```text
.
├── ansible.cfg
├── host.ini
├── deploy.yml
├── group_vars/
│   ├── all.yml
│   └── webserver.yml
└── roles/
    ├── debian/
    ├── server_setup/
    ├── app_setup/
    └── network/
```

### `ansible.cfg`

تنظیمات پیش‌فرض Ansible را مشخص می‌کند:

- `inventory = host.ini`: فایل inventory پیش‌فرض.
- `roles_path = ./roles`: مسیر roleهای محلی.
- `host_key_checking = False`: عدم بررسی کلید SSH میزبان.
- `deprecation_warnings = False`: مخفی‌کردن هشدارهای deprecation.

### `host.ini`

میزبان‌ها و گروه‌ها را تعریف می‌کند. در وضعیت فعلی:

```ini
[webserver]
server3

[ubuntu]
server3 ansible_host=192.168.1.5
```

مفسر Python برای گروه Ubuntu روی `/usr/bin/python3` تنظیم شده است.
اطلاعات ورود فعلی داخل این فایل نمونه هستند؛ برای محیط واقعی از SSH key و
Ansible Vault استفاده کنید و رمزها را در فایل عمومی نگه ندارید.

### `group_vars`

- `all.yml`: متغیرهای عمومی، ازجمله DNS serverها.
- `webserver.yml`: متغیرهای Vikunja، PostgreSQL، شبکه، Nginx و SSL.

متغیرهای مهم:

| متغیر | کاربرد |
|---|---|
| `vikunja_path_file` | مسیر نصب برنامه، پیش‌فرض `/opt/vikunja/` |
| `vikunja_url_public` | دامنه‌ی عمومی برنامه |
| `vikunja_service_secret` | secret سرویس Vikunja |
| `vikunja_database_*` | مشخصات اتصال و نام PostgreSQL |
| `docker_network_name` | نام شبکه‌ی مشترک Docker، پیش‌فرض `vikunja_net` |
| `nginx_path_file` | مسیر Compose و تنظیمات Nginx، پیش‌فرض `/opt/nginx/` |
| `nginx_http_port` / `nginx_https_port` | پورت‌های publish‌شده‌ی Nginx |
| `nginx_ssl_host_dir` | مسیر certificate روی میزبان |
| `nginx_ssl_generate_self_signed` | تولید خودکار certificate خودامضا |
| `nginx_ssl_valid_days` | مدت اعتبار certificate خودامضا |

مقدارهای `vikunja_service_secret` و `vikunja_database_password` حساس هستند.
آن‌ها را برای استفاده‌ی واقعی تغییر دهید یا با `ansible-vault` رمزنگاری کنید.

## وظیفه‌ی roleها

### `debian`

هنوز کامل نشده است

### `server_setup`

کارهای پایه‌ی سرور را انجام می‌دهد:

- به‌روزرسانی و upgrade بسته‌ها.
- نصب ابزارهای پایه مانند `curl`، `git`، `ufw` و `ca-certificates`.
- نصب Docker Engine و Docker Compose plugin.
- فعال‌کردن و اجرای سرویس Docker.
- اضافه‌کردن کاربرها به گروه Docker.
- تنظیم Docker registry mirror.
- بازکردن پورت‌های SSH/HTTP/HTTPS در UFW و فعال‌کردن سیاست deny برای ورودی‌ها.

این role نیز در حال حاضر task tag ندارد.

### `app_setup`

Vikunja و PostgreSQL را در مسیر `vikunja_path_file` deploy می‌کند:

1. ساخت پوشه‌های برنامه، فایل‌های پیوست و دیتابیس.
2. کپی `files/docker-compose.yml`.
3. رندر فایل `.env` از `templates/.env.j2`.
4. اجرای Docker Compose با ماژول `community.docker.docker_compose_v2`.

Compose برنامه از image `vikunja/vikunja:2.5.0` و PostgreSQL استفاده می‌کند.
سرویس `vikunja` و `db` روی شبکه‌ی خارجی مشترک `docker_network_name` قرار دارند
تا Nginx بتواند با نام `vikunja` به پورت داخلی `3456` متصل شود.

این role در `meta/main.yml` به `server_setup` و `network` وابسته است؛ بنابراین
در اجرای `app_setup` ابتدا dependencyها اجرا می‌شوند.

### `network`

شبکه و reverse proxy را آماده می‌کند:

- ساخت شبکه‌ی Bridge خارجی Docker.
- ساخت مسیر `/opt/nginx/`.
- ساخت مسیر certificateها.
- تولید certificate و private key خودامضا با OpenSSL، در صورت فعال‌بودن
  `nginx_ssl_generate_self_signed`.
- رندر `templates/nginx_config.txt.j2` به `nginx_config.txt`.
- کپی `files/docker-compose-ngnix.yml`.
- اجرای کانتینر `nginx:1.27-alpine`.

Nginx درخواست‌های HTTP را به HTTPS redirect می‌کند و در HTTPS، ترافیک را به
`http://vikunja:3456` reverse proxy می‌کند.

> نام فایل Compose طبق درخواست پروژه `docker-compose-ngnix.yml` است؛ املای
> `ngnix` عمداً حفظ شده است.

## پیش‌نیازها

- یک میزبان Ubuntu یا Debian با دسترسی SSH و `sudo`.
- Python 3 روی میزبان، معمولاً در `/usr/bin/python3`.
- نصب Ansible روی سیستم اجراکننده.
- collection موردنیاز:

```bash
ansible-galaxy collection install community.docker
```

- دسترسی شبکه برای دریافت packageها و imageهای Docker.
- آزادبودن پورت‌های `80` و `443`. اگر Nginx سیستم یا سرویس دیگری این پورت‌ها را
  اشغال کرده باشد، کانتینر Nginx start نمی‌شود.

## نصب و اجرا

### ۱. آماده‌سازی inventory و متغیرها

آدرس، کاربر و روش احراز هویت را در `host.ini` تنظیم کنید. سپس مقادیر دامنه،
secret و رمز PostgreSQL را در `group_vars/webserver.yml` تغییر دهید.

برای مثال:

```yaml
vikunja_url_public: "vikunja.example.test"
vikunja_path_file: "/opt/vikunja/"
docker_network_name: "vikunja_net"
nginx_http_port: 80
nginx_https_port: 443
```

اگر certificate معتبر را از بیرون provision می‌کنید، این گزینه را خاموش کنید:

```yaml
nginx_ssl_generate_self_signed: false
```

در این حالت باید فایل‌های زیر پیش از اجرای role در
`nginx_ssl_host_dir` وجود داشته باشند:

```text
<domain>.crt
<domain>.key
```

### ۲. بررسی اتصال و syntax

```bash
ansible all -i host.ini -m ping
ansible-playbook -i host.ini deploy.yml --syntax-check
```

### ۳. اجرای deployment

```bash
ansible-playbook -i host.ini deploy.yml
```

برای اجرای بخش deployment فعلی:

```bash
ansible-playbook -i host.ini deploy.yml --tags deploy
```

پس از اجرا، سرویس‌ها روی میزبان هدف در این مسیرها قرار می‌گیرند:

```text
/opt/vikunja/docker-compose.yml
/opt/vikunja/.env
/opt/nginx/docker-compose-ngnix.yml
/opt/nginx/nginx_config.txt
/etc/nginx/ssl/<domain>.crt
/etc/nginx/ssl/<domain>.key
```

### ۴. اتصال به Vikunja

اگر DNS واقعی ندارید، روی سیستم کلاینت در فایل hosts این خط را اضافه کنید:

```text
192.168.1.5    vikunja.example.test
```

سپس در مرورگر باز کنید:

```text
https://vikunja.example.test
```

برای certificate خودامضا، هشدار مرورگر طبیعی است. تست خط فرمان:

```bash
curl -k -I https://vikunja.example.test
```

## Tagها

### tagهای `app_setup`

- `install`: ساخت مسیرها، کپی Compose، ساخت `.env` و اجرای برنامه.
- `deploy`: تمام taskهای deployment برنامه.
- `docker`: اجرای Docker Compose برنامه.

نمونه:

```bash
ansible-playbook -i host.ini deploy.yml --tags install
ansible-playbook -i host.ini deploy.yml --tags docker
```

در این پروژه tagای با نام `app_setup` تعریف نشده است؛ برای اجرای taskهای
`app_setup` از `install`، `deploy` یا `docker` استفاده کنید.

### tagهای `network`

- `network`: ساخت شبکه‌ی Bridge مشترک.
- `install`: ساخت مسیرهای Nginx و رندر/کپی فایل‌های آن.
- `ssl`: ساخت مسیر SSL، تولید و بررسی certificate و رندر تنظیمات SSL.
- `deploy`: اجرای taskهای deployment role.
- `docker`: اجرای Compose Nginx.

نمونه:

```bash
ansible-playbook -i host.ini deploy.yml --tags network
ansible-playbook -i host.ini deploy.yml --tags ssl
ansible-playbook -i host.ini deploy.yml --tags docker
```

### `debian` و `server_setup`

این دو role در فایل فعلی taskهای tagدار ندارند؛ بنابراین با
`--tags install` یا `--tags deploy` انتخاب نمی‌شوند، مگر اینکه به taskهای آن‌ها
tag اضافه شود یا role بدون محدودیت tag اجرا شود.

## بررسی وضعیت و خطایابی

روی سرور:

```bash
sudo docker compose -f /opt/vikunja/docker-compose.yml ps
sudo docker compose -f /opt/nginx/docker-compose-ngnix.yml ps
sudo docker logs vikunja-nginx
sudo docker network inspect vikunja_net
sudo ss -ltnp | grep -E ':80|:443|:3456'
```

اگر خطای `address already in use` برای پورت ۸۰ یا ۴۴۳ گرفتید، ابتدا مشخص کنید
کدام سرویس پورت را اشغال کرده است:

```bash
sudo ss -ltnp | grep -E ':80|:443'
```

تا زمان مشخص‌شدن مالک پورت، سرویس فعلی را متوقف نکنید؛ ممکن است سایت یا reverse
proxy دیگری روی همان سرور در حال استفاده باشد.

# توضحات تکمیلی
## جدول متغیرهای `webserver.yml`

| Variable Name                      | Description (توضیحات)                                                                                                                                         | Default / Example Value                              | Type      | Notes (یادداشت‌ها)                                                                                           |
|------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------|-----------|--------------------------------------------------------------------------------------------------------------|
| `vikunja_path_file`                | مسیر ریشه روی هاست برای ذخیره‌سازی فایل‌های برنامه Vikunja، پیوست‌ها و داده‌های پایگاه داده.                                                                  | `/opt/vikunja/`                                      | `string`  | توسط نقش `app_setup` برای ایجاد زیرمسیرهای لازم استفاده می‌شود.                                            |
| `vikunja_url_public`               | نام دامنه عمومی (FQDN) که Vikunja از طریق آن در دسترس خواهد بود.                                                                                             | `vikunja.example.test`                               | `string`  | همچنین برای تعریف `nginx_server_name` و تولید گواهی خودامضا استفاده می‌شود.                               |
| `vikunja_service_secret`           | کلید مخفی مورد استفاده Vikunja برای عملیات رمزنگاری داخلی (مانند رمزگذاری نشست، JWT). **باید در محیط تولید تغییر داده شود.**                                  | `dbcd0b6b...c48354b`                                 | `string`  | مقدار حساس؛ در فایل `.env` با دسترسی `0600` ذخیره می‌شود.                                                  |
| `vikunja_database_host`            | نام هاست یا کانتینر سرور پایگاه داده PostgreSQL برای Vikunja.                                                                                                 | `db`                                                 | `string`  | به کانتینر پایگاه داده در شبکه Docker اشاره دارد.                                                          |
| `vikunja_database_password`        | رمز عبور کاربر پایگاه داده Vikunja. **باید در محیط تولید تغییر داده شود.**                                                                                    | `changeme`                                           | `string`  | مقدار حساس؛ در فایل `.env` ذخیره می‌شود.                                                                   |
| `vikunja_database_user`            | نام کاربری پایگاه داده Vikunja.                                                                                                                               | `vikunja`                                            | `string`  |                                                                                                              |
| `vikunja_database_name`            | نام پایگاه داده PostgreSQL مورد استفاده Vikunja.                                                                                                              | `vikunja`                                            | `string`  |                                                                                                              |
| `app_internal_port`                | پورت داخلی که برنامه Vikunja درون کانتینر خود روی آن گوش می‌دهد.                                                                                              | `3456`                                               | `integer` | این پورت هم برای کانتینر Vikunja و هم به عنوان پورت upstream برای Nginx (`nginx_upstream_port`) استفاده می‌شود. |
| `docker_network_name`              | نام شبکه پل Docker که توسط همه سرویس‌ها (Vikunja و Nginx) به اشتراک گذاشته می‌شود.                                                                            | `vikunja_net`                                        | `string`  | شبکه توسط نقش `webserver` ایجاد می‌شود و توسط هر دو پروژه compose استفاده می‌گردد.                        |
| `nginx_path_file`                  | مسیر روی هاست برای ذخیره فایل‌های تنظیمات Nginx، فایل محیطی و فایل Docker Compose.                                                                            | `/opt/nginx/`                                        | `string`  | توسط نقش `webserver` ایجاد می‌شود.                                                                          |
| `nginx_server_name`                | نام سرور (دامنه) مورد استفاده در میزبان مجازی Nginx و Common Name گواهی.                                                                                     | `{{ vikunja_url_public }}`                           | `string`  | از `vikunja_url_public` محاسبه می‌شود تا همگام بمانند.                                                     |
| `nginx_upstream_host`              | نام هاست یا کانتینر سرویس upstream Vikunja درون شبکه Docker.                                                                                                  | `vikunja`                                            | `string`  | باید با نام کانتینر Vikunja در فایل compose آن مطابقت داشته باشد.                                         |
| `nginx_upstream_port`              | پورتی که سرویس upstream Vikunja روی آن گوش می‌دهد.                                                                                                            | `3456`                                               | `integer` | برابر با `app_internal_port` است؛ برای وضوح بیشتر جداگانه تعریف شده است.                                   |
| `nginx_http_port`                  | پورت هاست که برای HTTP (پورت ۸۰) روی کانتینر Nginx نگاشت می‌شود.                                                                                              | `80`                                                 | `integer` | برای نمایش ریدایرکت HTTP به HTTPS استفاده می‌شود.                                                           |
| `nginx_https_port`                 | پورت هاست که برای HTTPS (پورت ۴۴۳) روی کانتینر Nginx نگاشت می‌شود.                                                                                           | `443`                                                | `integer` | برای پایان‌دهی TLS و ارائه ترافیک استفاده می‌شود.                                                          |
| `nginx_image`                      | تگ تصویر Docker برای پروکسی معکوس Nginx.                                                                                                                      | `nginx:1.27-alpine`                                  | `string`  | در فایل Compose Nginx مشخص می‌شود.                                                                          |
| `nginx_container_name`             | نامی که به کانتینر Nginx داده می‌شود.                                                                                                                         | `vikunja-nginx`                                      | `string`  | در Docker Compose و به عنوان شناسه استفاده می‌شود.                                                          |
| `nginx_ssl_host_dir`               | مسیر روی هاست برای ذخیره/تامین فایل‌های گواهی TLS و کلید خصوصی.                                                                                              | `/etc/nginx/ssl`                                     | `string`  | با دسترسی `0750` ایجاد می‌شود؛ کلید با `0600` تنظیم می‌گردد.                                               |
| `nginx_ssl_container_dir`          | مسیر درون کانتینر برای mount کردن گواهی و کلید TLS به صورت فقط‑خواندنی.                                                                                       | `/etc/nginx/ssl`                                     | `string`  | باید با مسیر ارجاع داده شده در فایل تنظیمات Nginx مطابقت داشته باشد.                                      |
| `nginx_ssl_certificate`            | نام فایل گواهی TLS (گواهی عمومی) درون `nginx_ssl_host_dir`.                                                                                                   | `{{ nginx_server_name }}.crt`                        | `string`  | در حالت خودامضا به صورت `server_name.crt` تولید می‌شود.                                                    |
| `nginx_ssl_certificate_key`        | نام فایل کلید خصوصی TLS درون `nginx_ssl_host_dir`.                                                                                                            | `{{ nginx_server_name }}.key`                        | `string`  | در حالت خودامضا به صورت `server_name.key` تولید می‌شود.                                                    |
| `nginx_ssl_generate_self_signed`   | پرچم بولی برای اینکه در صورت `true`، playbook با استفاده از OpenSSL یک گواهی خودامضا تولید کند.                                                              | `true`                                               | `boolean` | در صورت `false`، مدیر سیستم باید فایل‌های گواهی/کلید موجود را در `nginx_ssl_host_dir` فراهم کند.          |
| `nginx_ssl_valid_days`             | مدت اعتبار (به روز) برای گواهی خودامضا.                                                                                                                      | `365`                                                | `integer` | تنها زمانی استفاده می‌شود که `nginx_ssl_generate_self_signed` برابر `true` باشد.                           |

---

**یادداشت‌های تکمیلی: (webserver.yml)**

- تمام متغیرهای حساس (`vikunja_service_secret` و `vikunja_database_password`) در فایل‌های `.env` با مجوزهای محدود (`0600`) ذخیره شده و از لاگ‌های Ansible حذف می‌شوند (`no_log: true`).
- قالب تنظیمات Nginx (`nginx_config.txt.j2`) و فایل محیطی (`env.j2`) از این متغیرها برای تولید پیکربندی نهایی استفاده می‌کنند.
- متغیر `nginx_server_name` از `vikunja_url_public` مشتق می‌شود تا اطمینان حاصل شود که گواهی و میزبان مجازی از یک دامنه استفاده می‌کنند.
- پرچم `nginx_ssl_generate_self_signed` تولید گواهی‌ها را کنترل می‌کند؛ همچنین playbook قبل از راه‌اندازی Nginx وجود فایل‌های TLS مورد نیاز را بررسی می‌کند تا از شکست استقرار جلوگیری شود.

# output
خروجی های خاسته شده در آن جا قرار دارد 
فایل ها از 0-5 توسط دهفانی و شفیعی انحام شده

فایل های 06-07 توصط حمیدی انجام شده 
>output\04-06-07
