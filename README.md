برای اتصال به Vikunja از طریق Nginx:

روی کامپیوتر کلاینت، فایل hosts را ویرایش کنید.
در Windows:

text
C:\Windows\System32\drivers\etc\hosts
در Linux:

text
/etc/hosts
این خط را اضافه کنید:

text
192.168.1.5    vikunja.example.test
آدرس 192.168.1.5 همان IP موجود در 
host.ini
 است.

مطمئن شوید هر دو Compose روی سرور فعال هستند:
bash
sudo docker compose -f /opt/vikunja/docker-compose.yml ps
sudo docker compose -f /opt/nginx/docker-compose-ngnix.yml ps
باید سرویس‌های vikunja، db و nginx در وضعیت running باشند.