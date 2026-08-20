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
