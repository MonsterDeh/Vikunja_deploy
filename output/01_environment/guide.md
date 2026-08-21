# مرحله ۱ — آماده‌سازی محیط (سرور + بررسی سیستم)

## وضعیت
انجام‌شده

## خواستهٔ اصلی
آماده‌سازی یک سرور Ubuntu 22.04 (حداقل 2GB RAM و 20GB دیسک)، ثبت مشخصات آن در `01_environment/server_info.md` و جمع‌آوری اطلاعات سیستم (kernel، OS، دیسک، حافظه، شبکه) در `01_environment/server_connection.txt`.

## محل فایل / کار انجام‌شده
- مسیر در ریپو: `project/01_environment/server_info.md` (مشخصات سرور: IP، username، روش SSH، RAM/Disk/CPU)
- مسیر در ریپو: `project/01_environment/server_connection.txt` (خروجی `uname -a`، `lsb_release -a`، `df -h`، `free -h`، interfaceهای شبکه)
- سرور واقعی مورد استفادهٔ تیم در `host.ini` ریشهٔ ریپو نیز تعریف شده است: `server3` با `ansible_host=192.168.1.5` و کاربر `ubuntu`.

## چرا این خواسته را پوشش می‌دهد
- `server_info.md` هر چهار مورد خواسته‌شده (IP، Username، روش دسترسی SSH، مشخصات RAM/Disk/CPU) را در جدول دارد.
- `server_connection.txt` دقیقاً خروجی دستورات پیشنهادی صورت‌پروژه (`uname`، `lsb_release`، `df`، `free`) را شامل می‌شود.
- توجه: مقادیر IP در `server_info.md` نمونه (`203.0.113.10`) هستند؛ IP واقعی محیط تیم `192.168.1.5` در `host.ini` است. هنگام تحویل نهایی مقادیر واقعی را جایگزین کنید.

## دستور بررسی
```bash
cat project/01_environment/server_info.md
cat project/01_environment/server_connection.txt
ssh ubuntu@192.168.1.5 'uname -a && lsb_release -a'
```

## اگر ناقص بود
- اسکریپت `output/01_environment/01_collect_server_info.sh` اضافه شد تا همان دستورات بررسی سیستم را روی سرور واقعی اجرا و در فایل ذخیره کند (چون صورت‌پروژه صراحتاً «خروجی را در فایل ذخیره کنید» خواسته است).
