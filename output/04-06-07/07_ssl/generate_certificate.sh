#!/bin/bash
# تولید Self-Signed Certificate برای myapp.local
# اجرا روی سرور: sudo bash generate_certificate.sh

set -e

CERT_DIR="/etc/nginx/ssl"
DOMAIN="myapp.local"
DAYS_VALID=365

echo "== 1) ساخت پوشه‌ی certificates =="
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "== 2) تولید Private Key (2048-bit RSA) =="
openssl genrsa -out "${DOMAIN}.key" 2048

echo "== 3) ساخت Certificate Signing Request (CSR) =="
openssl req -new \
    -key "${DOMAIN}.key" \
    -out "${DOMAIN}.csr" \
    -subj "/C=IR/ST=Tehran/L=Tehran/O=DevOps-Homework/OU=Team/CN=${DOMAIN}"

echo "== 4) تولید Self-Signed Certificate با x509 =="
openssl x509 -req \
    -days ${DAYS_VALID} \
    -in "${DOMAIN}.csr" \
    -signkey "${DOMAIN}.key" \
    -out "${DOMAIN}.crt"

echo "== 5) تنظیم Permissions امن =="
chmod 600 "${DOMAIN}.key"
chmod 644 "${DOMAIN}.crt"
chown root:root "${DOMAIN}.key" "${DOMAIN}.crt"

echo
echo "== خلاصه =="
echo "Private key : ${CERT_DIR}/${DOMAIN}.key"
echo "Certificate : ${CERT_DIR}/${DOMAIN}.crt"
openssl x509 -in "${DOMAIN}.crt" -noout -dates -subject
