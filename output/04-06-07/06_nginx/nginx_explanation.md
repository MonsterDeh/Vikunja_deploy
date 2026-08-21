# توضیح Nginx Configuration برای Vikunja (اصلاح‌شده مطابق image واقعی)

## ⚠️ تغییر مهم نسبت به نسخه‌ی قبلی

نسخه‌ی قبلی این فایل بر اساس image‌های `vikunja/frontend` و `vikunja/api`
نوشته شده بود که **رسماً Deprecated (منسوخ) اعلام شدن**. Vikunja از نسخه‌ی
جدید همه‌چیز رو در یک image به اسم `vikunja/vikunja` ادغام کرده. این نسخه
مطابق همون image واقعی (که خودت از مستندات رسمی پیدا کردی) بازنویسی شده.

## طراحی (6.1)

| مورد | مقدار |
|---|---|
| Domain name | `myapp.local` |
| Application port | container `vikunja` روی پورت داخلی `3456` (هم UI هم API) |
| الگو | Reverse Proxy ساده — یک `location` برای همه‌چیز |

چون دیگه frontend و api جدا نیستن، نیازی به تفکیک مسیر با regex نیست؛
همه‌ی درخواست‌ها (چه صفحه‌ی وب، چه `/api/...`) به همون یک container
`vikunja:3456` فرستاده می‌شن.

## نکات Configuration (6.2)

1. **`listen 80`**: نسخه‌ی اولیه بدون SSL.
2. **`location /`**: تمام ترافیک به `http://vikunja:3456` proxy می‌شه.
3. **`client_max_body_size 20M`**: برای آپلود attachment.
4. **Headers**:
   - `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto` → همون دلایل قبلی (شناخت دامنه، IP واقعی کاربر، تشخیص http/https)
5. **`proxy_http_version 1.1` + `Upgrade`/`Connection`**: برای اطمینان از پشتیبانی احتمالی از WebSocket در آینده (بی‌ضرر است، الزامی نیست ولی best practice).

## فعال‌سازی (6.3)

```bash
sudo cp nginx_config.txt /etc/nginx/sites-available/vikunja
sudo ln -s /etc/nginx/sites-available/vikunja /etc/nginx/sites-enabled/vikunja
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

## تنظیم /etc/hosts (6.4)

روی سیستم محلی:
```
sudo nano /etc/hosts
```
```
SERVER_IP  myapp.local
```

## تست دسترسی (6.5)

```bash
curl http://localhost         # از خود سرور
curl http://myapp.local       # از سیستم محلی بعد از تنظیم hosts
curl -I http://myapp.local    # بررسی headers
```

انتظار: کد `200` و بارگذاری صفحه‌ی لاگین Vikunja.

### نکته‌ی مهم درباره‌ی هماهنگی با پورت compose

توی docker-compose واقعی که خودت پیدا کردی:
```yaml
ports:
  - 127.0.0.1:3456:3456
```
این پورت **فقط روی خود سرور (localhost)** باز شده، نه به بیرون. یعنی
Nginx باید **روی همون سرور** اجرا بشه تا بتونه به `127.0.0.1:3456` وصل
بشه (نه به اسم سرویس `vikunja` — چون این مقدار port فقط وقتی داخل
همون شبکه‌ی داکر کار می‌کنی معتبره).

**دو راه داری:**
1. اگه Nginx رو هم به‌عنوان یه container داخل همون `docker-compose.yml`
   اضافه کنی و روی همون شبکه‌ی داکر باشه → از اسم سرویس `vikunja:3456`
   استفاده کن (همون‌طور که در فایل بالا نوشته شده).
2. اگه Nginx رو مستقیماً روی خود سرور (نه داخل داکر) نصب کنی → باید
   `proxy_pass http://127.0.0.1:3456;` بنویسی، نه `http://vikunja:3456;`.

فایل `04_docker/docker-compose.yml` که براتون اضافه کردم، حالت (۱) رو
پیاده می‌کنه (Nginx هم داخل همون شبکه‌ی داکر است).
