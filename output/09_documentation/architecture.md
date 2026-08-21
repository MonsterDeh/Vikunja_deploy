# Architecture — Vikunja deployment

## Overview
A modern task-management application (Vikunja) containerized with Docker, running behind an Nginx reverse proxy that terminates TLS. The entire stack uses PostgreSQL as its database and is fully automated with Ansible roles for provisioning, configuration, and deployment.

---

## Diagram

```
                          Internet
                             |
                             v
                  +---------------------+
                  |   Ubuntu 22.04 VPS  |
                  |                     |
                  |  +---------------+  |
    HTTPS :443 -->|  |     Nginx     |  |
    HTTP  :80  -->|  | (reverse proxy|  |
                  |  |  + TLS term.) |  |
                  |  +-------+-------+  |
                  |          |          |
                  |     proxy_pass      |
                  |          |          |
                  |          v          |
                  |  +---------------+  |
                  |  |   Vikunja     |  |
                  |  |  (tasks app)  |  |
                  |  |  internal     |  |
                  |  |  port :3456   |  |
                  |  +-------+-------+  |
                  |          |          |
                  |   PostgreSQL        |
                  |   protocol          |
                  |          |          |
                  |          v          |
                  |  +---------------+  |
                  |  |  PostgreSQL   |  |
                  |  |  (db server)  |  |
                  |  |  port :5432   |  |
                  |  +---------------+  |
                  |                     |
                  |  All containers      |
                  |  share the Docker    |
                  |  network `vikunja_net` |
                  +---------------------+
```

---

## Components

1. **Nginx (reverse proxy)**  
   - Listens on ports 80 and 443 (host).  
   - Redirects all HTTP traffic to HTTPS.  
   - Terminates TLS using a certificate (self-signed or provided) mounted from the host at `/etc/nginx/ssl`.  
   - Proxies requests to the Vikunja container over the internal Docker network on port 3456.  
   - Configuration is generated from the Jinja2 template `nginx_config.txt.j2` and mounted read‑only into the container.

2. **Vikunja (application container)**  
   - Runs the official `vikunja/vikunja` image.  
   - Handles all application logic, user authentication, and task management.  
   - Listens internally on port 3456 (the port is exposed only to the Docker network, not to the host).  
   - Uses environment variables (from the `.env` file) to set:
     - Public URL (with `https://`)
     - Service secret (for cryptography)
     - Database connection parameters (host, user, password, database name)
   - Persists uploaded files in the host directory `./files` (mounted to `/app/vikunja/files`).

3. **PostgreSQL (database container)**  
   - Runs PostgreSQL 18 (official image).  
   - Stores all application data in a persistent volume (`./db` on the host, mounted to `/var/lib/postgresql`).  
   - Exposes port 5432 only inside the Docker network.  
   - Includes a health check (`pg_isready`) to ensure it is ready before Vikunja starts.

4. **Docker Compose & Ansible (automation)**  
   - Two separate Compose files are used:
     - `docker-compose.yml` – defines Vikunja + PostgreSQL.
     - `docker-compose-ngnix.yml` – defines Nginx.
   - Both services attach to the same pre‑created Docker bridge network `vikunja_net`.  
   - Ansible roles automate:
     - **app_setup** – creates directories, copies Compose files, renders the `.env` file, and runs `docker compose up`.
     - **network** – creates the shared Docker network, sets up Nginx directories, generates SSL certificates (if self‑signed), renders the Nginx environment and configuration files, and deploys the Nginx container.

5. **SSL/TLS**  
   - The certificate and private key are stored on the host in `{{ nginx_ssl_host_dir }}` (default: `/etc/nginx/ssl`).  
   - They are mounted read‑only into the Nginx container at `/etc/nginx/ssl`.  
   - If `nginx_ssl_generate_self_signed` is `true`, the Ansible role automatically generates a self‑signed certificate with OpenSSL.  
   - The playbook verifies that both files exist before starting Nginx, preventing deployment failures.

---

## Request flow

1. A client sends an HTTPS request to `https://vikunja.example.test/` (or whatever public domain is configured).  
2. Nginx receives the request on port 443, terminates the TLS connection using the certificate and key from the mounted volume, and checks the virtual host name against `server_name`.  
3. Nginx proxies the request to the Vikunja container using `proxy_pass http://vikunja:3456` over the `vikunja_net` network.  
4. Vikunja processes the request (e.g., renders a page, handles an API call, or processes a form).  
5. If database access is needed, Vikunja connects to the PostgreSQL container via the internal hostname `db` (as defined by `VIKUNJA_DATABASE_HOST`) and port 5432.  
6. PostgreSQL returns the requested data, Vikunja generates the response, and it flows back through Nginx to the client.  
7. Static files (attachments) are served directly from the mounted `files` volume.

---

## Deployment automation (Ansible)

- **Variables** – all configurable parameters are centralized in `webserver.yml` (e.g., paths, ports, secrets, SSL settings).  
- **Roles** – separate roles for the application and the reverse proxy ensure clear separation of concerns.  
- **Idempotency** – tasks like directory creation, file copying, and certificate generation are designed to be idempotent.  
- **Handlers** – Nginx is restarted only when configuration files change.  
- **Security** – sensitive values are stored in `.env` files with `0600` permissions and are excluded from Ansible logs (`no_log: true`).

---

## Summary

This architecture provides a secure, containerized, and fully automated deployment of Vikunja. By separating the reverse proxy, application, and database into distinct containers, it offers flexibility, scalability, and ease of maintenance. The use of Ansible ensures that the entire environment can be reproducibly built on any target server with minimal manual intervention.