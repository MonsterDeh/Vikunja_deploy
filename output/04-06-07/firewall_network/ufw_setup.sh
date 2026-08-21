#!/bin/bash
# تنظیم UFW Firewall برای سرور Vikunja
# اجرا روی سرور: sudo bash ufw_setup.sh

set -e

echo "== نصب ufw (در صورت نیاز) =="
apt-get update -y
apt-get install -y ufw

echo "== سیاست پیش‌فرض: رد همه‌ی ورودی‌ها، قبول همه‌ی خروجی‌ها =="
ufw default deny incoming
ufw default allow outgoing

echo "== باز کردن پورت‌های ضروری =="
ufw allow 22/tcp   comment 'SSH'
ufw allow 80/tcp   comment 'HTTP'
ufw allow 443/tcp  comment 'HTTPS'

echo "== فعال‌سازی =="
ufw --force enable

echo "== وضعیت نهایی =="
ufw status verbose
