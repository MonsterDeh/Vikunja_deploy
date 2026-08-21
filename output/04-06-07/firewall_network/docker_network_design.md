# طراحی Docker Network برای Vikunja (اصلاح‌شده مطابق image واقعی)

## ⚠️ تغییر نسبت به نسخه‌ی قبلی
نسخه‌ی قبلی سه container (frontend/api/db) فرض کرده بود. با image واقعی
(`vikunja/vikunja`) فقط **دو تا container برنامه‌ای** داریم: `vikunja` و `db`،
به‌علاوه‌ی `nginx` که جلوشون قرار می‌گیره.

## طراحی شبکه

```
                    اینترنت
                       │
                  (پورت 80/443)
                       │
                 ┌───────────┐
                 │   nginx   │  ← تنها container با port mapping به بیرون
                 │  (proxy)  │
                 └─────┬─────┘
                       │
              شبکه‌ی داخلی: vikunja_net (bridge)
                       │
              ┌────────┴────────┐
              │                 │
        ┌───────────┐     ┌───────────┐
        │  vikunja   │     │    db     │
        │(UI + API)  │─────│(postgres) │
        │ port 3456  │     │ port 5432 │
        └───────────┘     └───────────┘
```

## پیاده‌سازی در docker-compose.yml

```yaml
networks:
  vikunja_net:
    driver: bridge

services:
  db:
    networks:
      - vikunja_net
    # بدون ports به بیرون — فقط از طریق شبکه‌ی داخلی توسط vikunja دیده می‌شود

  vikunja:
    networks:
      - vikunja_net
    ports:
      - "127.0.0.1:3456:3456"   # فقط برای دیباگ لوکال، نه دسترسی عمومی

  nginx:
    networks:
      - vikunja_net
    ports:
      - "80:80"
      - "443:443"
```

فایل کامل و قابل‌اجرا در `04_docker/docker-compose.yml` قرار دارد.

## دلایل طراحی

1. **یک نقطه‌ی ورود (Single entry point)**: کاربر واقعی از اینترنت فقط با
   Nginx (پورت 80/443) طرف است؛ `db` هیچ پورتی به بیرون ندارد.
2. **پورت 127.0.0.1:3456 روی خود سرویس vikunja**: این پورت طبق کانفیگ
   رسمی خود Vikunja فقط روی loopback (`127.0.0.1`) باز شده، یعنی حتی
   از شبکه‌ی محلی هم در دسترس نیست — فقط از خود سرور. این یک لایه‌ی
   امنیتی اضافه محسوب می‌شود، مستقل از UFW.
3. **Isolation با bridge network اختصاصی**: همه‌ی سرویس‌ها روی
   `vikunja_net` هستند، نه شبکه‌ی پیش‌فرض داکر که بین همه‌ی پروژه‌های
   روی سرور مشترک است.
4. **Service discovery با نام سرویس**: `vikunja` به `db` با نام سرویس
   (`VIKUNJA_DATABASE_HOST: db`) وصل می‌شود، و `nginx` به `vikunja` هم
   با نام سرویس (`proxy_pass http://vikunja:3456`) — نه IP، چون IP
   داخلی داکر با هر بار `up` عوض می‌شود.

## هماهنگی با تیم
- **امین (Docker/Compose)**: سرویس‌های `vikunja` و `db` را طبق فایل
  رسمی نوشته (که همون فایلی است که شما پیدا کردید)؛ من فقط `networks`
  و سرویس `nginx` را به آن اضافه کردم.
- **امیرحسین (Ansible)**: در playbook، UFW باید فقط 22/80/443 باز کند؛
  پورت 3456 چون فقط روی loopback است اصلاً نیازی به بستن جداگانه در
  UFW ندارد (از بیرون دیده نمی‌شود).
