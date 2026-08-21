# بخش رضا — Nginx، SSL، Firewall، Network (پروژه Vikunja)

⚠️ **نسخه‌ی اصلاح‌شده**: این نسخه بر اساس image واقعی و فعلی Vikunja
(`vikunja/vikunja:2.5.0` یکپارچه) نوشته شده، نه نسخه‌ی قدیمی و
Deprecated (`vikunja/frontend` + `vikunja/api` جدا).

## ساختار

```
04_docker/
  docker-compose.yml         → همون compose واقعی (vikunja + db) + سرویس nginx اضافه‌شده

06_nginx/
  nginx_config.txt            → Reverse proxy config (HTTP) به سمت vikunja:3456
  nginx_explanation.md        → توضیح کامل + دستورات فعال‌سازی و تست
  hosts_file.txt               → نمونه محتوای /etc/hosts

07_ssl/
  generate_certificate.sh      → اسکریپت تولید Self-Signed Certificate (تست‌شده و کار می‌کند)
  certificate_info.txt         → قالب خروجی اطلاعات certificate
  nginx_ssl_config.txt         → Config نهایی Nginx با SSL + HTTP→HTTPS redirect
  test_results.txt             → قالب نتایج تست redirect/HTTPS

firewall_network/
  ufw_setup.sh                  → اسکریپت تنظیم UFW (پورت 22/80/443)
  firewall_status.txt           → قالب خروجی ufw status
  docker_network_design.md      → طراحی شبکه‌ی Docker (nginx → vikunja → db)
```

## چطور خودت اجرا کنی (از صفر تا تست)

### ۱) آماده‌سازی فولدر پروژه روی سرور
```bash
mkdir -p vikunja-project/{files,db}
cd vikunja-project
# فایل‌های این زیپ (04_docker, 06_nginx, 07_ssl, firewall_network) رو همینجا کپی کن
```

### ۲) بالا آوردن اپلیکیشن + دیتابیس + nginx (بدون SSL)
```bash
docker compose -f 04_docker/docker-compose.yml up -d
docker compose -f 04_docker/docker-compose.yml ps
```
باید `vikunja`, `db`, `nginx` هر سه `running`/`healthy` باشند.

### ۳) تست اولیه (بدون SSL)
```bash
curl -I http://localhost
```
باید کد `200` بگیری (صفحه‌ی لاگین Vikunja).

اگر می‌خوای از سیستم محلی خودت (نه سرور) هم تست کنی، طبق `06_nginx/hosts_file.txt`
دامنه رو به IP سرور map کن، بعد:
```bash
curl http://myapp.local
```

### ۴) فعال کردن SSL
```bash
sudo bash 07_ssl/generate_certificate.sh
```
این اسکریپت certificate رو توی `/etc/nginx/ssl/` روی سرور (نه داخل کانتینر)
می‌سازه. برای استفاده‌ی nginx (که داخل کانتینره)، باید این مسیر رو به‌عنوان
volume به سرویس nginx اضافه کنی — در `04_docker/docker-compose.yml` خط
مربوطه (کامنت‌شده) رو باز کن:
```yaml
    volumes:
      - ./06_nginx/nginx_config.txt:/etc/nginx/conf.d/default.conf:ro
      - /etc/nginx/ssl:/etc/nginx/ssl:ro     # <- این خط رو اضافه/فعال کن
```
و کانفیگ رو به نسخه‌ی SSL عوض کن:
```yaml
      - ./07_ssl/nginx_ssl_config.txt:/etc/nginx/conf.d/default.conf:ro
```
بعد:
```bash
docker compose -f 04_docker/docker-compose.yml up -d --force-recreate nginx
```

### ۵) تست HTTPS
```bash
curl -Ik https://myapp.local          # -k چون certificate self-signed است
curl -I http://myapp.local            # باید 301 به https ریدایرکت بده
```

### ۶) تنظیم فایروال
```bash
sudo bash firewall_network/ufw_setup.sh
sudo ufw status verbose
```

## نکات مهم

- در compose واقعی، پورت `127.0.0.1:3456:3456` روی خود vikunja **فقط برای
  دیباگ لوکال** نگه داشته شده؛ مسیر اصلی کاربر باید از Nginx (80/443) باشد.
- فایل‌های `*_results.txt` / `*_status.txt` / `certificate_info.txt` با
  مقادیر **نمونه** پر شده‌اند. بعد از اجرای واقعی روی سرور خودت، خروجی
  واقعی دستورات (`curl`, `ufw status`, `openssl x509 ...`, `nginx -t`)
  را جایگزین این نمونه‌ها کن.
- `myapp.local`، `VIKUNJA_SERVICE_SECRET` و `POSTGRES_PASSWORD` را قبل
  از استفاده‌ی واقعی حتماً با مقادیر خودت/امن جایگزین کن.
