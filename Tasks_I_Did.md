# گزارش ممیزی جامع پروژه Ansible

## ۱. نمای کلی و هدف پروژه (Executive Summary)

این پروژه برای آماده‌سازی یک سرور Ubuntu/Debian و استقرار سامانهٔ Vikunja طراحی شده است. معماری اجرایی آن شامل اجزای زیر است:

- نصب و پیکربندی Docker Engine و Docker Compose Plugin
- ایجاد شبکهٔ خارجی Docker با نام `vikunja_net`
- اجرای Vikunja با Image نسخهٔ `2.5.0`
- اجرای PostgreSQL با Image نسخهٔ `18`
- ایجاد Nginx به‌عنوان Reverse Proxy
- Redirect ترافیک HTTP به HTTPS
- تولید Self-signed TLS Certificate
- اعمال قوانین UFW برای پورت‌های SSH، HTTP و HTTPS

Playbook اصلی فقط Role `app_setup` را مستقیماً فراخوانی می‌کند؛ بااین‌حال، `roles/app_setup/meta/main.yml` به Roleهای `server_setup` و `network` وابسته است، بنابراین آن‌ها به‌صورت Dependency اجرا می‌شوند.

وضعیت پروژه: از نظر معماری کلی نسبتاً کامل و قابل‌استفاده است، اما همچنان حالت نیمه‌محصولی/در حال توسعه دارد؛ زیرا Secrets در کد به‌صورت Plain Text قرار گرفته‌اند، تست خودکار واقعی وجود ندارد، `requirements.yml` تعریف نشده و Role `debian` و بخشی از Role `server_setup` کامنت یا غیرفعال هستند.

---

## ۲. آناتومی ساختار (Directory Tree)

```text
.
├── ansible.cfg
├── deploy.yml
├── host.ini
├── README.md
├── group_vars
│   ├── all.yml
│   └── webserver.yml
└── roles
    ├── app_setup
    │   ├── defaults/main.yml
    │   ├── files/docker-compose.yml
    │   ├── handlers/main.yml
    │   ├── meta/main.yml
    │   ├── tasks/main.yml
    │   ├── templates/.env.j2
    │   ├── tests/
    │   └── vars/main.yml
    ├── debian
    │   ├── defaults/main.yml
    │   ├── handlers/main.yml
    │   ├── meta/main.yml
    │   ├── tasks/main.yml
    │   ├── templates/apt.j2
    │   ├── templates/sudoers.j2
    │   ├── tests/
    │   └── vars/main.yml
    ├── network
    │   ├── defaults/main.yml
    │   ├── files/docker-compose-ngnix.yml
    │   ├── handlers/main.yml
    │   ├── meta/main.yml
    │   ├── tasks/main.yml
    │   ├── templates/.env.j2
    │   ├── templates/nginx_config.txt.j2
    │   └── tests/
    └── server_setup
        ├── defaults/main.yml
        ├── handlers/main.yml
        ├── meta/main.yml
        ├── tasks/main.yml
        ├── templates/main.yml
        ├── tests/
        └── vars/main.yml
```

فایل‌های `project`، `reza_devops_v2` و `temp` در این ممیزی بررسی نشده‌اند.

### Playbook اصلی

در `deploy.yml`:

- Target host برابر `webserver` است.
- `become: yes` برای اجرای دستورات با سطح دسترسی Root فعال است.
- `gather_facts: yes` فعال است.
- Role `app_setup` با `include_role` اجرا می‌شود.
- فقط Tag سطح Play با مقدار `deploy` تعریف شده است.
- Role `debian` و `server_setup` در Playbook به‌صورت مستقیم کامنت شده‌اند.

---

## ۳. گزارش دقیق کارهای انجام‌شده (Tasks & Implementations)

### Role: `server_setup`

این Role از طریق Dependency در `app_setup` اجرا می‌شود.

سیستم هدف: عمدتاً Ubuntu/Debian مبتنی بر APT. Repository داکر به‌صورت صریح برای Ubuntu تنظیم شده و روی RedHat/CentOS قابل اجرا نیست.

| نام تسک | ماژول | آرگومان‌های کلیدی | شرح دقیق عملکرد |
|---|---|---|---|
| Update apt cache and upgrade packages | `apt` | `update_cache=yes`, `upgrade=dist`, `cache_valid_time=3600` | Cache مخازن APT را به‌روزرسانی و تمام بسته‌ها را با سیاست `dist-upgrade` ارتقا می‌دهد. |
| Install required base packages | `apt` | `curl`, `wget`, `git`, `vim`, `htop`, `ufw`, `ca-certificates`, `gnupg`, `lsb-release`, `state=present` | ابزارهای پایهٔ سیستم، UFW، گواهی‌های CA و ابزارهای لازم برای Repository داکر را نصب می‌کند. |
| Add Docker GPG key | `apt_key` | URL رسمی کلید Docker | کلید امضای Repository داکر را اضافه می‌کند. استفاده از `apt_key` در نسخه‌های جدید Ansible/debian رویکرد قدیمی محسوب می‌شود. |
| Add Docker apt repository | `apt_repository` | `deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable` | Repository داکر را اضافه می‌کند. معماری به‌صورت Hard-code روی `amd64` قرار گرفته است. |
| Install Docker Engine and Compose plugin | `apt` | `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-compose-plugin` | Docker Engine و Compose V2 Plugin را نصب می‌کند. |
| Start and enable Docker service | `systemd` | `name=docker`, `state=started`, `enabled=yes` | سرویس Docker را اجرا و برای Boot بعدی فعال می‌کند. |
| Add user(s) to the docker group | `user` | `name={{ item }}`, `groups={{ docker_group }}`, `append=yes` | کاربران موجود در `docker_users` را به گروه Docker اضافه می‌کند. با `loop` اجرا می‌شود. |
| Set Docker registry mirrors | `ansible.builtin.copy` | `/etc/docker/daemon.json`, `docker_registry_mirrors` | فایل تنظیمات Docker Daemon را تولید و Registry Mirrorهای سفارشی را ثبت می‌کند. در صورت تغییر، Handler `Restart Docker` فراخوانی می‌شود. |
| Allow SSH through the firewall | `ufw` | `rule=allow`, `port=22`, `proto=tcp` | دسترسی SSH را مجاز می‌کند. |
| Allow HTTP through the firewall | `ufw` | `rule=allow`, `port=80`, `proto=tcp` | دسترسی HTTP را مجاز می‌کند. |
| Allow HTTPS through the firewall | `ufw` | `rule=allow`, `port=443`, `proto=tcp` | دسترسی HTTPS را مجاز می‌کند. |
| Enable UFW with a default-deny policy | `ufw` | `state=enabled`, `policy=deny` | UFW را فعال و سیاست پیش‌فرض ورودی را روی Deny قرار می‌دهد. |

#### Taskهای کامنت‌شده

این Taskها اجرا نمی‌شوند:

- نصب Nginx سیستمی
- Start و Enable سرویس Nginx سیستمی

در این پروژه Nginx داخل Container اجرا می‌شود، بنابراین این بخش‌ها ظاهراً کنار گذاشته شده‌اند.

---

### Role: `network`

این Role شبکهٔ Docker و Reverse Proxy را ایجاد می‌کند.

سیستم هدف: Linux دارای Docker و OpenSSL. نصب OpenSSL از طریق Package Manager سیستم انجام می‌شود.

| نام تسک | ماژول | آرگومان‌های کلیدی | شرح دقیق عملکرد |
|---|---|---|---|
| Create shared Docker bridge network | `community.docker.docker_network` | `name={{ docker_network_name }}`, `driver=bridge`, `state=present` | شبکهٔ خارجی Docker را ایجاد می‌کند تا Containerهای Vikunja و Nginx بتوانند با یکدیگر ارتباط داشته باشند. |
| Create Nginx project directory | `ansible.builtin.file` | مسیر `nginx_path_file`, `state=directory`, mode `0755` | مسیر پروژهٔ Nginx، به‌صورت پیش‌فرض `/opt/nginx/`، ایجاد می‌شود. |
| Create host directory for TLS certificates | `ansible.builtin.file` | مسیر `nginx_ssl_host_dir`, mode `0750` | پوشهٔ ذخیرهٔ Certificate و Private Key را ایجاد می‌کند. |
| Install OpenSSL | `ansible.builtin.package` | `name=openssl`, `state=present` | فقط در صورت فعال بودن `nginx_ssl_generate_self_signed` اجرا می‌شود. |
| Generate self-signed TLS certificate and private key | `ansible.builtin.command` | `openssl req -x509`, RSA 2048، `-days`, `-subj`, `subjectAltName` | Certificate و Private Key خودامضا تولید می‌کند. با `creates` نسبت به Certificate تاحدی Idempotent شده است. |
| Set TLS private key permissions | `ansible.builtin.file` | mode `0600`, owner/group `root` | دسترسی Private Key را محدود می‌کند. |
| Set TLS certificate permissions | `ansible.builtin.file` | mode `0644`, owner/group `root` | Certificate را برای خواندن عمومی‌تر تنظیم می‌کند. |
| Check TLS certificate | `ansible.builtin.stat` | مسیر Certificate | وجود Certificate را در متغیر `nginx_tls_certificate` ثبت می‌کند. |
| Check TLS private key | `ansible.builtin.stat` | مسیر Private Key | وجود Key را در متغیر `nginx_tls_private_key` ثبت می‌کند. |
| Verify TLS files exist before starting Nginx | `ansible.builtin.assert` | `stat.exists` برای هر دو فایل | اگر فایل‌های TLS موجود نباشند، اجرای Role را متوقف می‌کند. |
| Render Nginx environment file | `ansible.builtin.template` | `templates/.env.j2`, mode `0600`, `no_log=true` | متغیرهای Image، پورت‌ها، نام Container و مسیر TLS را به فایل `.env` تبدیل می‌کند. |
| Render Nginx reverse proxy configuration | `ansible.builtin.template` | `nginx_config.txt.j2` | تنظیمات HTTP/HTTPS، Redirect، Reverse Proxy، Headerها و Logها را تولید می‌کند. |
| Copy Nginx Docker Compose file | `ansible.builtin.copy` | `src={{ nginx_compose_filename }}` | فایل Compose را به `/opt/nginx/` منتقل می‌کند. نام فایل به‌صورت `docker-compose-ngnix.yml` تعریف شده است. |
| Deploy Nginx reverse proxy | `community.docker.docker_compose_v2` | `project_src`, `files`, `state=present` | Container Nginx را ایجاد یا به‌روزرسانی می‌کند. |

#### منطق Nginx

- پورت 80 به HTTPS Redirect می‌شود.
- پورت 443 با TLS 1.2 و TLS 1.3 فعال است.
- ترافیک به `http://vikunja:3456` Proxy می‌شود.
- Headerهای `Host`، `X-Real-IP`، `X-Forwarded-*` و WebSocket Upgrade تنظیم شده‌اند.
- محدودیت Upload روی `20M` قرار دارد.
- خطاهای 502، 503 و 504 به صفحهٔ `50x.html` هدایت می‌شوند.

---

### Role: `app_setup`

این Role سرویس Vikunja و PostgreSQL را اجرا می‌کند.

سیستم هدف: Linux دارای Docker Engine، Compose V2 و Collection `community.docker`.

| نام تسک | ماژول | آرگومان‌های کلیدی | شرح دقیق عملکرد |
|---|---|---|---|
| Create root directory for Vikunja | `ansible.builtin.file` | مسیر `vikunja_path_file`, owner/group `root`, mode `0755` | پوشهٔ اصلی Deployment را ایجاد می‌کند؛ پیش‌فرض `/opt/vikunja/` است. |
| Create files directory for Vikunja attachments | `ansible.builtin.file` | مسیر `files`, owner/group عددی `1000`, mode `0750` | Storage پایدار Attachments Vikunja را آماده می‌کند. |
| Create db directory for PostgreSQL persistence | `ansible.builtin.file` | مسیر `db`, owner/group عددی `999`, mode `0750` | Storage پایدار PostgreSQL را آماده می‌کند. این UID/GID به Image خاص وابسته است. |
| Copy docker compose file | `ansible.builtin.copy` | `src=docker-compose.yml`, مقصد `/opt/vikunja/docker-compose.yml` | Compose مربوط به Vikunja و PostgreSQL را منتقل می‌کند. با تغییر فایل، `Restart Vikunja` Notify می‌شود. |
| Render secret environment file | `ansible.builtin.template` | `.env.j2`, mode `0600`, `no_log=true` | Secrets و پارامترهای اتصال دیتابیس را Render می‌کند. با تغییر، Vikunja Restart می‌شود. |
| Run Docker compose of Vikunja | `community.docker.docker_compose_v2` | `project_src`, `state=present` | سرویس‌های `vikunja` و `db` را ایجاد یا به‌روزرسانی می‌کند. |

#### Compose Vikunja

- Image برنامه: `vikunja/vikunja:2.5.0`
- Image دیتابیس: `postgres:18`
- Database Type: PostgreSQL
- پورت داخلی Vikunja: `3456`
- Binding پورت برنامه فقط روی `127.0.0.1` انجام می‌شود.
- دیتابیس دارای Healthcheck است.
- سرویس Vikunja به سالم بودن دیتابیس وابسته است.
- شبکه با `external: true` استفاده می‌شود و باید قبلاً ایجاد شده باشد.

---

### Role: `debian`

این Role در Playbook اصلی فعال نیست؛ خط `include_role` آن کامنت شده است.

| نام تسک | ماژول | آرگومان‌های کلیدی | شرح دقیق عملکرد |
|---|---|---|---|
| Set custom debian sources list | `ansible.builtin.template` | `apt.j2` به `/etc/apt/sources.list.d/custom-mirrors.list` | بر اساس نسخهٔ Debian، Codename مناسب مانند `bullseye`، `bookworm` یا `trixie` را انتخاب کرده و Repositoryهای Mirror را تولید می‌کند. |
| Remove legacy custom mirror list | `file` | کامنت‌شده | حذف فایل قدیمی Mirror را انجام نمی‌دهد. |
| Install sudo | `apt` | کامنت‌شده | نصب sudo غیرفعال است. |
| Ensure user is a member of sudo group | `user` | کامنت‌شده | افزودن کاربر متصل‌شونده به گروه sudo غیرفعال است. |
| Template sudoers entry | `template` | کامنت‌شده، با `validate=visudo -cf %s` | تولید فایل sudoers و Handler `reload sudo` غیرفعال است. |

---

## ۴. قابلیت‌های پیاده‌سازی‌شده (Features)

### سرویس‌ها و Daemonها

- Docker Engine
- Docker Compose Plugin
- Vikunja
- PostgreSQL
- Nginx Reverse Proxy
- UFW Firewall

### شبکه و پورت‌ها

- شبکهٔ خارجی Docker با نام `vikunja_net`
- پورت `22/tcp`: SSH
- پورت `80/tcp`: HTTP و Redirect به HTTPS
- پورت `443/tcp`: HTTPS
- پورت `3456`: فقط روی Loopback میزبان برای Vikunja Publish می‌شود.

### امنیت و TLS

- TLS 1.2 و TLS 1.3
- Cipherهای محدودشده با حذف `aNULL`، `MD5` و `3DES`
- Private Key با Permission `0600`
- فایل‌های `.env` با Permission `0600`
- فعال‌سازی UFW با Default Policy برابر Deny
- Certificate به‌صورت Self-signed تولید می‌شود؛ بنابراین برای محیط Production مناسب نیست مگر اینکه با Certificate معتبر جایگزین شود.

### پارامترهای قابل سفارشی‌سازی

مهم‌ترین متغیرهای قابل تغییر در `group_vars/webserver.yml` و Defaults Role `network`:

- `vikunja_path_file`
- `vikunja_url_public`
- `vikunja_service_secret`
- `vikunja_database_host`
- `vikunja_database_password`
- `vikunja_database_user`
- `vikunja_database_name`
- `app_internal_port`
- `docker_network_name`
- `nginx_path_file`
- `nginx_server_name`
- `nginx_upstream_host`
- `nginx_upstream_port`
- `nginx_http_port`
- `nginx_https_port`
- `nginx_image`
- `nginx_container_name`
- `nginx_ssl_host_dir`
- `nginx_ssl_generate_self_signed`
- `nginx_ssl_valid_days`
- `nginx_compose_filename`
- `docker_registry_mirrors`
- `docker_users`

---

## ۵. بررسی Handlers (رویدادها)

| Role | Handler | Trigger | عملکرد |
|---|---|---|---|
| `app_setup` | `Restart Vikunja` | تغییر Compose یا `.env` | اجرای `community.docker.docker_compose_v2` با `state=restarted` در مسیر Vikunja |
| `network` | `Restart Nginx` | تغییر Certificate، `.env`، کانفیگ Nginx یا Compose | Restart Compose پروژهٔ Nginx |
| `server_setup` | `Restart Docker` | تغییر `/etc/docker/daemon.json` | Restart سرویس Docker با ماژول `service` |
| `debian` | `Update apt cache` | تغییر فایل Mirror | اجرای `apt update_cache=yes` |
| `debian` | `reload sudo` | در صورت فعال شدن Task sudoers | اجرای `/usr/sbin/visudo -c`؛ این Handler در واقع Reload سرویس sudo انجام نمی‌دهد و فقط Syntax را بررسی می‌کند. |

نکته: Handlerها فقط در صورت `changed` شدن Taskهای Notifyکننده اجرا می‌شوند و معمولاً در انتهای Play اجرا خواهند شد.

---

## ۶. وابستگی‌ها و پیش‌نیازها (Dependencies)

### Collection مورد نیاز

کد از ماژول‌های زیر استفاده می‌کند:

```text
community.docker.docker_network
community.docker.docker_compose_v2
```

بنابراین Collection زیر باید نصب شود:

```bash
ansible-galaxy collection install community.docker
```

هیچ فایل `requirements.yml` یا `collections/requirements.yml` در پروژه وجود ندارد؛ این یک نقص مستندسازی و Reproducibility است.

### وابستگی Roleها

در `roles/app_setup/meta/main.yml`:

```yaml
dependencies:
  - server_setup
  - network
```

بنابراین اجرای `app_setup` به‌صورت طبیعی باید ابتدا `server_setup` و سپس `network` را اجرا کند.

Roleهای `debian`، `network` و `server_setup` وابستگی خارجی Role ندارند.

---

## ۷. شکاف‌ها، خطاهای احتمالی و کارهای ناقص (Gaps & Incomplete Works)

### Secrets ناامن

مقادیر زیر در Repository به‌صورت Plain Text قرار گرفته‌اند:

- `ansible_password`
- `ansible_become_password`
- `vikunja_service_secret`
- `vikunja_database_password`

استفاده از `ansible-vault` یا Secret Backend ضروری است. مقدار `changeme` برای دیتابیس در محیط Production قابل قبول نیست.

### عدم اجرای واقعی Syntax Check در محیط فعلی

اجرای `ansible-playbook --syntax-check deploy.yml` در محیط Windows به خطای Runtime زیر متوقف شد:

```text
OSError: [WinError 87] The parameter is incorrect
```

این خطا قبل از Parse شدن Playbook و ناشی از ناسازگاری اجرای Ansible در این محیط Windows است؛ بنابراین از این خروجی نمی‌توان نتیجه گرفت که YAML پروژه حتماً Syntax Error دارد یا ندارد.

### ناسازگاری سیستم‌عامل

Role `server_setup` کاملاً بر APT و Repository Ubuntu Docker متکی است:

```text
https://download.docker.com/linux/ubuntu
```

بنابراین:

- روی Ubuntu مناسب است.
- روی Debian ممکن است Repository و Package Resolution شکست بخورد.
- روی RedHat/CentOS قابل اجرا نیست.
- معماری فقط `amd64` تعریف شده و روی ARM شکست خواهد خورد.

### Role `debian` غیرفعال است

در `deploy.yml`، اجرای Role `debian` کامنت شده است. بنابراین Mirrorهای Debian و تنظیمات sudoers در اجرای فعلی اعمال نمی‌شوند.

### Taskهای کامنت‌شده

در Role `debian` بخش‌های زیر کامنت شده‌اند:

- حذف Mirror قدیمی
- نصب sudo
- تعیین کاربر متصل‌شونده
- افزودن کاربر به گروه sudo
- ایجاد `/etc/sudoers.d`
- تولید فایل sudoers

در Role `server_setup` نیز نصب و اجرای Nginx سیستمی کامنت شده است.

### متغیرهای بدون Default

Role `app_setup` در `defaults/main.yml` هیچ متغیر کاربردی تعریف نمی‌کند. اگر Role خارج از گروه `webserver` یا بدون `group_vars/webserver.yml` اجرا شود، متغیرهای زیر Undefined خواهند شد:

- `vikunja_path_file`
- `vikunja_url_public`
- `vikunja_service_secret`
- `vikunja_database_*`
- `app_internal_port`
- `docker_network_name`

همچنین Role `server_setup` به `ansible_user` وابسته است؛ در اجرای Local یا Inventory ناقص ممکن است `docker_users` مقدار نامعتبر دریافت کند.

### مشکل احتمالی Tagها

در `deploy.yml`، خود `include_role` فقط Tag `deploy` دارد. بنابراین اجرای زیر ممکن است Role را اصلاً وارد نکند:

```bash
ansible-playbook deploy.yml --tags install
ansible-playbook deploy.yml --tags network
```

در حالی که Taskهای داخلی Roleها این Tagها را دارند. برای رفتار قابل پیش‌بینی باید Tagها روی `include_role` یا با `apply: tags:` به‌صورت صریح اعمال شوند.

### Certificate خودامضا

Self-signed Certificate برای Production مناسب نیست و باعث Warning مرورگر و عدم اعتماد Clientها می‌شود. باید امکان استفاده از Certificate معتبر ACME یا Certificate Provision‌شده فراهم شود.

### نبود تست واقعی

فایل‌های `roles/*/tests/test.yml` صرفاً Playbookهای بسیار ساده برای اجرای Role روی `localhost` هستند و Assertions، Molecule، Testinfra یا سناریوی Idempotency ندارند.

### مشکلات نگهداری

- استفاده از ماژول‌های کوتاه‌شده مانند `apt`، `user` و `systemd` به‌جای FQCN
- استفاده از `apt_key` قدیمی
- نام فایل `docker-compose-ngnix.yml` دارای Typo است؛ بهتر است به `docker-compose-nginx.yml` تغییر کند.
- UID/GIDهای `1000` و `999` به‌صورت Hard-code تعریف شده‌اند.
- `host_key_checking = False` ریسک MITM در SSH ایجاد می‌کند.
- Registry Mirrorهای سفارشی به سرویس‌های خارجی وابسته‌اند و ممکن است Availability یا Trust آن‌ها تغییر کند.
- `group_vars/all.yml` شامل DNS Serverهایی است که در هیچ Taskی مصرف نمی‌شوند.

---

## ۸. جمع‌بندی نهایی و نحوه‌ی اجرا (Final Verdict & How to Run)

### پیش‌نیازهای سرور

برای Ubuntu 22.04 یا 24.04:

```bash
sudo apt update
sudo apt install -y python3 python3-pip openssh-server
```

روی سیستم کنترل‌کننده:

```bash
python3 -m pip install --user ansible-core
ansible-galaxy collection install community.docker
```

فایل `host.ini` باید با SSH Key و Secrets امن اصلاح شود. قراردادن Password خام در Inventory توصیه نمی‌شود.

بررسی اتصال:

```bash
ansible all -i host.ini -m ping
```

بررسی Syntax در محیط Linux:

```bash
ansible-playbook -i host.ini deploy.yml --syntax-check
```

اجرای کامل:

```bash
ansible-playbook -i host.ini deploy.yml
```

اجرای Deployment:

```bash
ansible-playbook -i host.ini deploy.yml --tags deploy
```

پس از اجرا، مسیرهای اصلی روی سرور عبارت‌اند از:

```text
/opt/vikunja/docker-compose.yml
/opt/vikunja/.env
/opt/nginx/docker-compose-ngnix.yml
/opt/nginx/nginx_config.txt
/etc/nginx/ssl/<domain>.crt
/etc/nginx/ssl/<domain>.key
```

### رأی نهایی

پروژه از نظر طراحی کلی، Separation of Concerns مناسبی میان آماده‌سازی سرور، شبکه، Application و Reverse Proxy دارد و استفاده از Handler، Template، Docker Compose و Assert نشان‌دهندهٔ بلوغ نسبی کد است. بااین‌حال، برای Production واقعی هنوز نیازمند اصلاح جدی در مدیریت Secrets، تعریف `requirements.yml`، تست‌پذیری، پشتیبانی شفاف از نسخه‌های سیستم‌عامل، حذف Taskهای کامنت‌شده، اصلاح Tagها و جایگزینی Certificate خودامضا با TLS معتبر است. در وضعیت فعلی، پروژه را می‌توان یک Deployment قابل‌استفاده برای محیط آزمایشی یا نیمه‌Production دانست، نه یک Automation کاملاً Hardened و آمادهٔ محیط حساس.

output/environment/server_connection.txt