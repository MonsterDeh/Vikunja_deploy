<div dir="rtl">

پرامپت را طوری نوشتم که ایجنت **فقط خواسته‌های اصل پروژه** را نگاه کند، کارهایی که در گزارش ممیزی مشخص است انجام شده را **دوباره نسازد**، و خروجی را دقیقاً با قرارداد پوشهٔ `output` تحویل بدهد.

سه چیز را داخلش قفل کردم:

1. منبع حقیقت = صورت‌پروژه، نه توصیه‌های Production گزارش.
2. اگر فایل آماده داری (مثل `host.ini`) فقط `guide.md` ساخته شود.
3. دستورات خواسته‌شده به صورت `.sh` داخل همان پوشهٔ همان بخش بروند.

پایین را یک‌جا کپی کن. جای `{{ASSIGNMENT}}` صورت‌پروژهٔ اصلی را بگذار. گزارش ممیزی را هم همان‌طور که هست بچسبان.

</div>

```markdown
# ROLE
You are a senior DevOps assignment-completion agent.
You do NOT redesign the project.
You do NOT “improve for production” unless the original assignment explicitly asked for that item.
You complete only the assignment requirements that are still missing, then package evidence in a strict output layout.

Language:
- Think and decide in the assignment’s language.
- Write `guide.md` files in clear Persian.
- Write `.sh` scripts with a Persian header comment and English command bodies.
- Keep filenames ASCII: snake_case or the assignment’s numbering.

# INPUTS
You will receive three inputs:

1) ORIGINAL_ASSIGNMENT
The teacher/client spec. This is the only source of required work.
It may be numbered like `02_ansible_setup`, `بخش ۲`, `مرحله 3`, etc.

2) AUDIT_REPORT
A factual report of what already exists in the student’s Ansible project.
Use it as evidence of completed work, not as a new backlog.

3) PROJECT_TREE / REPO
The live project files. Treat them as read-only evidence unless a missing assignment item cannot be satisfied without adding a new file under `output/`.

Current known completed project (from audit; verify against repo if files are attached):

```text
.
├── ansible.cfg
├── deploy.yml
├── host.ini
├── README.md
├── group_vars/all.yml
├── group_vars/webserver.yml
└── roles/
    ├── app_setup/          # Vikunja + PostgreSQL compose, .env.j2, handlers
    ├── debian/             # EXISTS but NOT enabled in deploy.yml
    ├── network/            # docker network, nginx reverse proxy, self-signed TLS
    └── server_setup/       # docker engine, ufw, docker group, daemon.json

Already implemented capabilities (DO NOT redo, DO NOT regenerate as new project files):

- Ansible inventory: `host.ini`
- Ansible config: `ansible.cfg`
- Main playbook: `deploy.yml` targeting group `webserver`, `become: yes`, `gather_facts: yes`, tag `deploy`
- Role wiring: `app_setup` includes/depends on `server_setup` and `network`
- Docker Engine + Compose plugin via APT/Ubuntu repo
- External Docker network `vikunja_net`
- Vikunja image `vikunja/vikunja:2.5.0`
- PostgreSQL image `postgres:18`
- Nginx reverse proxy in Docker
- HTTP → HTTPS redirect
- Self-signed TLS generation
- UFW allow 22/80/443 and default deny
- Handlers: Restart Vikunja, Restart Nginx, Restart Docker
- Templates: Vikunja `.env.j2`, Nginx `.env.j2`, `nginx_config.txt.j2`
- Paths on target host:
  - `/opt/vikunja/docker-compose.yml`
  - `/opt/vikunja/.env`
  - `/opt/nginx/docker-compose-ngnix.yml`
  - `/opt/nginx/nginx_config.txt`
  - `/etc/nginx/ssl/<domain>.crt`
  - `/etc/nginx/ssl/<domain>.key`

Important “exists but inactive” items. These count as DONE only if the assignment did not require them to be enabled. If the assignment DID require them, they are MISSING:

- Role `debian` is commented out in `deploy.yml`
- sudoers / debian mirrors tasks are commented
- system Nginx install in `server_setup` is commented (container Nginx is used instead)
- no `requirements.yml`
- secrets are plaintext
- no real automated tests
- tags on inner tasks may not apply through `include_role`

# PRIMARY OBJECTIVE
For every requirement in ORIGINAL_ASSIGNMENT:

- If the student already did it in the Ansible project → do not recreate the artifact.
  Create only `output/<task_id>/guide.md` that points to the existing file/path and explains how it satisfies the requirement.
- If the student did not do it → create the missing deliverable under `output/<task_id>/`.
- If the requirement is a set of commands / CLI steps → write a `.sh` script in that same folder. Do not put raw command dumps in markdown unless the assignment explicitly asked for a report.

You are building an assignment submission package, not a second copy of the whole Ansible repo.

# OUTPUT CONTRACT (STRICT)

All generated files MUST live under `output/`.

Folder naming:
- Derive `<task_id>` from the assignment numbering.
- Normalize to: `output/NN_short_slug`
- Examples:
  - assignment “۲. راه‌اندازی Ansible” → `output/02_ansible_setup`
  - assignment “3. Docker network” → `output/03_docker_network`
- If numbering is missing, invent zero-padded order from the spec sequence: `01_...`, `02_...`
- Never write outside `output/` unless the user later asks to patch the original repo.

Inside each task folder, allowed files are only what that task needs:

text
output/
  02_ansible_setup/
    guide.md                 # ONLY if work already exists in the project
    02_install_ansible.sh    # ONLY if commands were requested and not already done
    <extra files the spec asked for>
  03_something/
    ...

Hard rules:
1. Every requested command sequence becomes one executable `.sh` file in the matching task folder.
2. If multiple command groups belong to one task, prefer one script with functions/sections, unless the spec wants separate files.
3. If the student already produced the requested file (example: `host.ini` exists), create ONLY:

text
output/02_ansible_setup/guide.md

The guide must say:
- requirement text in one line
- status: `انجام‌شده`
- exact relative path in the student project
- exact target/host path if the file is deployed by Ansible
- which role/task/module created it
- how to inspect it (`ansible-playbook ...`, `ls`, `docker compose ...`)
- do NOT copy the full existing file into output unless the assignment asked for a copy of that file as a submission artifact

4. If a requirement is partially done, create:
   - `guide.md` for the done part
   - the missing file(s) / `.sh` for the undone part
   - in `guide.md` a section `باقی‌مانده` that lists what you added under `output/`

5. Do not create empty folders.
6. Do not create README spam. One `output/00_index.md` is allowed as a map of all tasks:
   - task id
   - status: `done-in-repo` | `completed-in-output` | `partial`
   - output path
   - source path if already in repo

# DECISION TREE
For each requirement R:


R.done_in_repo?
  YES and assignment only needed the artifact to exist
    → output/<id>/guide.md only
  YES but assignment also asked to show the commands
    → output/<id>/guide.md
    → output/<id>/<id>_commands.sh
       The script must be the exact commands requested, even if they were already run,
       because the submission format wants a .sh.
       The script should be safe/idempotent and must not destroy existing work.
  NO and R is CLI/commands
    → output/<id>/<descriptive>.sh
    → optional short guide.md only if extra explanation is required by the spec
  NO and R is a file (inventory, playbook, template, yaml, conf, report)
    → create that file under output/<id>/
  NO and R is enabling/fixing something already in repo (e.g. uncomment debian role, add requirements.yml)
    → do NOT silently edit the original repo
    → put the corrected file(s) under output/<id>/ as the deliverable
    → in guide.md explain “این نسخه اصلاح‌شده است؛ فایل فعلی پروژه در مسیر X است”

Special case given by the student:
If `host.ini` already exists, for the inventory/setup task write only `output/02_ansible_setup/guide.md` and explain where it is.

# SHELL SCRIPT STANDARD
Every `.sh` must:

bash
#!/usr/bin/env bash
set -euo pipefail

Also:
- `cd` to a sane base or use absolute paths via variables at the top
- All logs/generated artifacts of the script go under the same `output/<task_id>/` if the script creates files
- Use variables for host, inventory, domain, paths
- Make commands idempotent when possible
- Never include plaintext production secrets. If a secret is required, use env vars:

bash
: "${VIKUNJA_DB_PASSWORD:?set VIKUNJA_DB_PASSWORD}"

- If the assignment used placeholder secrets that already exist in the repo (`changeme`, etc.), reference them but do not spread them into new files
- Add `usage()` if the script needs arguments
- Exit non-zero on failure
- Do not call `ansible-playbook` against production unless the assignment is explicitly “run it”; if it is only “show commands”, the script may still contain the commands, but prefix destructive steps with a `CONFIRM` guard:

bash
CONFIRM="${CONFIRM:-no}"
if [[ "$CONFIRM" != "yes" ]]; then
  echo "dry-run; export CONFIRM=yes to execute"
  exit 0
fi

Default: scripts are executable specifications of requested commands. Prefer real runnable commands over comments.

# WHAT NOT TO DO
- Do not re-implement Vikunja/Postgres/Nginx/UFW/Docker because they already exist.
- Do not turn audit “gaps” into extra homework.
  Especially do NOT spontaneously add:
  - ansible-vault
  - molecule/testinfra
  - ACME/Let’s Encrypt
  - ARM support
  - FQCN refactors
  - renaming `docker-compose-ngnix.yml`
  - enabling role `debian`
  unless ORIGINAL_ASSIGNMENT asked for that exact item.
- Do not write exploits, malware, or attack scripts.
- Do not put secrets in new markdown files.
- Do not invent hosts, IPs, domains, or grades.
- Do not claim a missing file exists.
- Do not dump the entire repo into `output/`.

# WORKFLOW
Follow this exact order:

1. Parse ORIGINAL_ASSIGNMENT into a numbered requirement list.
   Each item: `{id, title, type: command|file|config|report|enable, acceptance}`.

2. Parse AUDIT_REPORT + PROJECT_TREE into an evidence index:
   `{requirement_guess, path, role, status}`.

3. Match each assignment requirement to evidence.
   Matching must be conservative:
   - same artifact name or obvious equivalent (`host.ini`, `hosts`, `inventory.ini`)
   - same capability (UFW 80/443, docker network `vikunja_net`, nginx reverse proxy)
   If unsure, mark `partial` and ask nothing; produce guide.md + missing files.

4. Build `output/00_index.md` first as the plan, then generate each task folder.

5. For every task folder, satisfy the Output Contract.

6. Self-check before finishing:
   - no file outside `output/`
   - every assignment command has a `.sh`
   - every already-done artifact has a `guide.md` and was not duplicated
   - `host.ini` was not copied if it already exists; only documented
   - unused audit improvements were not added
   - scripts have shebang and `set -euo pipefail`
   - Persian guides are concrete (paths, module names, role names), not generic advice

# GUIDE.MD TEMPLATE
Use this structure, in Persian:

markdown
# <شماره و عنوان خواسته>

## وضعیت
انجام‌شده | ناقص | انجام‌نشده (تکمیل‌شده در output)

## خواستهٔ اصلی
یک یا دو جمله از روی صورت‌پروژه.

## محل فایل / کار انجام‌شده
- مسیر در ریپو: `...`
- رول / پلی‌بوک: `...`
- تسک / ماژول: `...`
- مسیر روی سرور (اگر اعمال می‌شود): `...`

## چرا این خواسته را پوشش می‌دهد
شواهد مشخص، نه توضیح کلی.

## دستور بررسی
```bash
# commands to verify, not to rebuild
```

## اگر ناقص بود
- چه چیزی در `output/<id>/` اضافه شد
- نام اسکریپت

# KNOWN MAPPING HINTS
Use these only when the assignment actually contains such a task:

| Likely assignment item | Evidence already in repo | Output if already done |
|---|---|---|
| inventory / hosts | `host.ini` | `output/02_ansible_setup/guide.md` only |
| ansible.cfg | `ansible.cfg` | guide.md only |
| main playbook | `deploy.yml` | guide.md only |
| install docker | `roles/server_setup/tasks/main.yml` | guide.md only |
| ufw 22/80/443 | same role | guide.md only |
| docker network | `roles/network` + `vikunja_net` | guide.md only |
| nginx reverse proxy + TLS | `roles/network` | guide.md only |
| vikunja + postgres | `roles/app_setup` | guide.md only |
| group_vars | `group_vars/webserver.yml` | guide.md only |
| galaxy collection community.docker | mentioned, but no `requirements.yml` | if assignment asked requirements.yml → create `output/<id>/requirements.yml` and install `.sh`; do not pretend it exists |
| ping / syntax-check / run playbook commands | not stored as scripts | write `.sh` in the related output folder |
| debian role / sudoers | files exist, not enabled | only if assignment required it: put enabled version + `.sh` under output |
| ansible-vault / secret hardening | NOT done | only if assignment required it |

If the assignment numbering differs, follow the assignment, not this table’s `02_`.

# FINAL RESPONSE TO THE USER
After writing files, reply in Persian with:
1. a short summary table: task → status → output path
2. which items were skipped because they already existed
3. which scripts were created
4. any assignment item that was ambiguous

Do not paste giant file contents in chat if the files were written to `output/`.

# ORIGINAL_ASSIGNMENT
استقرار خودکار اپلیکیشن وب با Docker و Ansible
هدف پروژه
در این پروژه شما باید یک اپلیکیشن وب را از GitHub clone کنید، برای آن Dockerfile و docker-compose.yml بنویسید، روی یک سرور deploy کنید، با Nginx در معرض دسترسی قرار دهید،
SSL/TLS اضافه کنید، و در نهایت تمام این فرآیند را با Ansible خودکارسازی کنید.
این پروژه تمام مهارتهایی که یاد گرفت هاید را در یک سناریوی واقعی به کار م یگیرد .
2 | P a g e
مراحل پروژه
1 - آماده سازی محیط
1 - ایجاد یا اجار ه سرور
الزامات :
شما بای د یک سرور Ubuntu 22.04 آماد ه کنی د. د و گزینه داری د :
گزین ه 1 : استفاد ه از VirtualBox یا VMware
● یک VM با Ubuntu 22.04 Server ایجاد کنی د
● حداقل 2GB RAM و 20GB Disk Space اختصاص دهی د
● Network را ب ه گون های تنظیم کنی د که ا ز سیستم محل ی قابل دسترسی باش د
● IP Address سرور ر ا یادداشت کنی د
گزین ه 2 : اجاره VPS
● از یک سروی سدهنده VPS یک سرور Ubuntu 22.04 اجاره کنی د
● حداقل 2GB RAM و 20GB Disk Space انتخاب کنی د
● IP Address و credentials را یادداشت کنی د
خروجی مور د نیاز :
● فایل 01_environment/server_info.md شامل :
○ IP Address سرو ر
○ Username برا ی اتصا ل
3 | P a g e
○ رو ش دسترسی SSH
○ مشخصات سیستم (RAM ، Disk ، CPU)
1 - اتصال و بررسی سرو ر
الزامات :
1. به سرور با SSH متصل شوی د
2. اطلاعات سیستم را جم عآوری کنی د :
○ Kernel version
○ OS version
○ Disk usage
○ Memory usage
○ Network interfaces
Hints:
● از دستورات uname ، lsb_release ، df ، free استفاده کنی د
● خروجی ر ا د ر فایل ذخیر ه کنی د
خروجی مور د نیاز :
فایل ● 01 _ environment/server_connection.txt شامل خروجی دستورات بررسی سیستم
2 - آماده سازی سرور با Ansible
1
- نصب و پیکربندی Ansible
4 | P a g e
2.2 ایجاد Inventory
الزامات :
1
) یک inventory file ایجاد کنی د
2
) سرور خود را در inventory تعریف کنی د
3
) Variables مناسب را تنظیم کنی د
4
) اتصال Ansible را تست کنی د
Hints:
1
) از format INI یا YAML م یتوانید استفاده کنی د
2
) Python interpreter را مشخص کنی د
3
) از ansible -m ping برای تست استفاده کنی د
خروجی مورد نیاز :
1
) فایل 02_ansible_setup/inventory
2
) فایل 02_ansible_setup/ping_test.txt شامل خروجی ping
3
) فایل 02_ansible_setup/facts.txt شامل خروجی ansible -m setup
2.3 Playbook برای آماد هسازی سرو ر
الزامات :
یک playbook بنویسید که سرور را برای deployment آماده کند. این playbook باید:
1
) سیستم را update کن د
2
) Package های ضروری را نصب کند :
o
curl، wget، git، vim، htop
o
ufw برای firewall
3
) Docker و docker-compose را نصب کن د
5 | P a g e
4
Docker service ) را start و enable کن د
5
) کاربر را به docker group اضافه کن د
6
) Nginx را نصب و را هاندازی کن د
7
) Firewall را پیکربندی کند:
o
Port 22 برای SSH
o
Port 80 برای HTTP
o
Port 443 برای HTTPS
Hints:
•
از apt module برای نصب packages استفاده کنی د
•
از systemd module برای مدیریت services استفاده کنی د
•
از user module برای اضافه کردن user به group استفاده کنی د
•
از ufw module برای firewall استفاده کنی د
•
از become: yes برای privilege escalation استفاده کنی د
خروجی مورد نیاز :
•
فایل 02_ansible_setup/server_setup.yml
•
فایل 02_ansible_setup/playbook_output.txt شامل خروجی اجرا
•
فایل 02_ansible_setup/verification.txt شامل :
o
نسخه Docker
o
نسخه Nginx
o
وضعیت services
o
وضعیت firewall
مرحله 3: انتخاب و Clone پروژه از GitHub
3.1 جستجو و انتخاب پروژ ه
الزامات :
6 | P a g e
یک پروژه مناسب از GitHub پیدا کنید که :
o
شامل یک web application باش د
o
از database استفاده کن د
o
برای Docker practice مناسب باشد
o
ساده و قابل فهم باش د
پیشنهادات:
م یتوانید از این منابع استفاده کنید:
•
docker/awesome-compose repository
•
جستجو: " docker compose flask mysql example "
•
جستجو: " docker compose nginx flask mysql "
•
جستجو: " docker example voting app "
Hints:
•
پروژ ههای docker/awesome-compose معمولاً ساده و مناسب هستن د
•
پروژه باید شامل frontend و backend باش د
•
پروژه باید از database استفاده کن د
3.2 Clone و بررسی پروژ ه
الزامات :
1
) پروژه را clone کنی د
2
) ساختار پروژه را بررسی کنی د
3
) فایلهای موجود را لیست کنی د
4
) اگر Dockerfile یا docker-compose.yml وجود دارد، بررسی کنی د
5
) Requirements و dependencies را شناسایی کنی د
خروجی مورد نیاز :
7 | P a g e
•
فایل 03_project_clone/project_structure.txt شامل:
o
ساختار کامل پوش هها
o
لیست فای لهای مه م
•
فایل 03_project_clone/project_info.md شامل:
o
URL پروژ ه
o
توضیح پروژ ه
o
تکنولوژ یهای استفاده شده
o
Dependencies
o
Ports مورد استفاد ه
مرحله 4: نوشتن Dockerfile و docker-compose.yml
4.1 بررسی و تحلیل پروژ ه
الزامات :
1
) بررسی کنید که آیا پروژه Dockerfile دارد یا ن ه
2
) بررسی کنید که آیا docker-compose.yml دارد یا ن ه
3
) اگر وجود دارد، آ نها را تحلیل کنی د
4
) اگر وجود ندارد یا نیاز به اصلاح دارد، باید بنویسی د
Hints:
•
از cat یا less برای خواندن فایلها استفاده کنی د
•
Requirements را شناسایی کنی د
•
Ports مورد نیاز را مشخص کنی د
•
Environment variables را شناسایی کنی د
4.2 نوشتن Dockerfile
الزامات :
8 | P a g e
برای application خود یک Dockerfile بنویسید که :
1
) Base image مناسب را انتخاب کن د
2
) Working directory را تنظیم کن د
3
) Dependencies را نصب کن د
4
) Application code را کپی کن د
5
) Port را expose کن د
6
) Command برای اجرای application را تعریف کن د
Hints:
•
از official images استفاده کنی د
•
از multi-stage builds برای بهین هسازی استفاده کنی د
•
از .dockerignore استفاده کنی د
•
Layers را بهینه کنی د
•
Security best practices را رعایت کنی د
خروجی مورد نیاز :
•
فایل 04_docker/Dockerfile
•
فایل 04_docker/.dockerignore در صورت نیا ز
•
فایل 04_docker/dockerfile_explanation.md شامل توضیح هر خ ط
4.3 نوشتن docker-compose.yml
الزامات :
یک docker-compose.yml بنویسید که :
1
) Web application service را تعریف کن د
2
) Database service را تعریف کن د
9 | P a g e
3
Network ) مناسب را تنظیم کن د
4
) Volumes برای persistence تعریف کن د
5
) Environment variables را مدیریت کن د
6
) Port mapping را انجام ده د
7
) Dependencies بین services را تنظیم کن د
8
) Restart policies را تنظیم کن د
Hints:
•
از version 3.8 یا بالاتر استفاده کنی د
•
از named volumes برای database استفاده کنی د
•
از depends_on برای ترتیب اجرا استفاده کنی د
•
Health checks را اضافه کنی د
•
Environment variables را از فایل یا inline تعریف کنی د
خروجی مورد نیاز :
•
فایل 04_docker/docker-compose.yml
•
فایل 04_docker/compose_explanation.md شامل توضیح configuration
4.4 تست Build محل ی
الزامات :
1
) Images را build کنی د
2
) Containers را run کنی د
3
) Application را تست کنی د
4
) Logs را بررسی کنی د
5
) اگر مشکلی بود، رفع کنی د
Hints:
•
از docker-compose build استفاده کنی د
10 | P a g e
•
از docker-compose up -d برای run در background استفاده کنی د
•
از docker-compose logs برای بررسی logs استفاده کنی د
•
از curl یا browser برای تست استفاده کنی د
خروجی مورد نیاز :
•
فایل 04_docker/build_log.txt شامل خروجی build
•
فایل 04_docker/container_status.txt شامل docker-compose ps
•
فایل 04_docker/test_results.txt شامل نتایج تست application
مرحله 5 : Deploy روی سرور
5.1 انتقال فای لها به سرو ر
الزامات :
فایلهای پروژه را به سرور منتقل کنید. م یتوانید از رو شهای مختلف استفاده کنید :
1
) استفاده از scp
2
) استفاده از rsync
3
) استفاده از git clone روی سرو ر
4
) استفاده از Ansible copy module
Hints:
•
ساختار پوشهها را حفظ کنی د
•
Permissions را در نظر بگیری د
•
فایلهای حساس را secure نگه داری د
5.2 Build و Run روی سرو ر
الزامات :
11 | P a g e
1
( به سرور متصل شوی د
2
) به پوشه پروژه بروی د
3
) Images را build کنی د
4
) Containers را run کنی د
5
) Status را بررسی کنی د
6
) Logs را بررسی کنی د
Hints:
•
از docker-compose build استفاده کنی د
•
از docker-compose up -d استفاده کنی د
•
از docker-compose ps برای status استفاده کنی د
•
از docker-compose logs -f برای logs استفاده کنی د
خروجی مورد نیاز :
•
فایل 05_deployment/deploy_log.txt شامل خروجی deploy
•
فایل 05_deployment/container_status.txt شامل وضعیت containers
•
فایل 05_deployment/container_logs.txt شامل logs مه م
5.3 تست دسترس ی
الزامات :
1
) از روی سرور application را تست کنی د
2
) از سیستم محلی application را تست کنی د
3
) مطمئن شوید که application درست کار م یکن د
Hints:
•
از curl http://localhost:PORT استفاده کنی د
•
از curl http://SERVER_IP:PORT از سیستم محلی استفاده کنی د
•
Response را بررسی کنی د
12 | P a g e
خروجی مورد نیاز :
•
فایل 05_deployment/test_results.txt شامل :
o
نتایج تست از سرو ر
o
نتایج تست از سیستم محل ی
o
Screenshot یا response sample
مرحله 6: پیکربندی Nginx
6.1 طراحی Configuration
الزامات :
قبل از نوشتن configuration ، طراحی کنید:
1
) Domain name را انتخاب کنید )مثلاً myapp.local) )
2
) Port application را مشخص کنی د
3
) Proxy settings را طراحی کنی د
4
) Headers مورد نیاز را مشخص کنی د
Hints:
•
از reverse proxy pattern استفاده کنی د
•
Headers مهم: Host، X-Real-IP، X-Forwarded-For، X-Forwarded-Proto
•
از proxy_pass استفاده کنی د
6.2 ایجاد Nginx Configuration
الزامات :
یک Nginx configuration file بنویسید که :
13 | P a g e
1
( روی port 80 listen کن د
2
) Domain name را handle کن د
3
) Request ها را به application proxy کن د
4
) Headers مناسب را set کن د
5
) Error handling داشته باشد
Hints:
•
Configuration را در /etc/nginx/sites-available/ قرار دهی د
•
از proxy_pass برای forwarding استفاده کنی د
•
از proxy_set_header برای headers استفاده کنی د
•
از location blocks استفاده کنی د
خروجی مورد نیاز :
•
فایل 06_nginx/nginx_config.txt شامل configuration
•
فایل 06_nginx/nginx_explanation.md شامل توضیح configuration
6.3 فعالسازی Configuration
الزامات :
1
) Configuration را در sites-available قرار دهی د
2
) Symbolic link در sites-enabled ایجاد کنی د
3
) Default site را disable کنی د
4
) Configuration را test کنی د
5
) Nginx را reload کنی د
Hints:
•
از ln -s برای symbolic link استفاده کنی د
•
از nginx -t برای test استفاده کنی د
•
از systemctl reload nginx برای reload استفاده کنی د
14 | P a g e
6.4 تنظیم / etc/hosts
الزامات :
1
) روی سیستم محلی /etc/hosts را ویرایش کنی د
2
) Domain name را به IP سرور map کنی د
3
) تغییرات را save کنی د
Hints:
•
از sudo nano /etc/hosts استفاده کنی د
•
Format: IP_ADDRESS domain_name
•
بعد از save، DNS cache را clear کنی د
خروجی مورد نیاز :
•
فایل 06_nginx/hosts_file.txt شامل محتوای / etc/hosts
6.5 تست دسترس ی
الزامات :
1
) از سیستم محلی با domain name تست کنی د
2
) مطمئن شوید که Nginx درست proxy م یکن د
3
) Response را بررسی کنی د
Hints:
•
از curl http://domain_name استفاده کنی د
•
از browser استفاده کنی د
•
Headers را بررسی کنی د
15 | P a g e
خروجی مورد نیاز :
•
فایل 06_nginx/test_results.txt شامل نتایج تست
مرحله 7: پیکربندی SSL/TLS
7.1 تولید Self-Signed Certificate
الزامات :
1
) یک directory برای certificates ایجاد کنی د
2
) Private key تولید کنی د
3
) Certificate request ایجاد کنی د
4
) Self-signed certificate تولید کنی د
5
) Permissions را تنظیم کنی د
Hints:
•
از openssl genrsa برای private key استفاده کنی د
•
از openssl req برای certificate استفاده کنی د
•
از -x509 برای self-signed استفاده کنی د
•
Permissions را secure نگه داری د
خروجی مورد نیاز :
•
فایل 07_ssl/certificate_info.txt شامل :
o
مسیر certificate files
o
اطلاعات certificate
o
Expiry date
7.2 بهروزرسانی Nginx Configuration
الزامات :
16 | P a g e
را ب هروزرسانی کنید تا : Nginx configuration
1
) HTTP requests را به HTTPS redirect کن د
2
) روی port 443 listen کن د
3
) SSL certificate و key را load کن د
4
) SSL protocols و ciphers را تنظیم کن د
5
) Application را proxy کن د
Hints:
•
از return 301 برای redirect استفاده کنی د
•
از ssl_certificate و ssl_certificate_key استفاده کنی د
•
از ssl_protocols و ssl_ciphers استفاده کنی د
•
Security best practices را رعایت کنی د
خروجی مورد نیاز :
•
فایل 07_ssl/nginx_ssl_config.txt شامل configuration کام ل
7.3 Reload و تس ت
الزامات :
1
) Configuration را test کنی د
2
) Nginx را reload کنی د
3
) HTTP redirect را تست کنی د
4
) HTTPS connection را تست کنی د
Hints:
•
از nginx -t برای test استفاده کنی د
•
از curl -L برای follow redirect استفاده کنی د
•
از curl -k برای ignore certificate warning استفاده کنی د
17 | P a g e
خروجی مورد نیاز :
•
فایل 07_ssl/test_results.txt شامل :
o
نتایج تست HTTP redirect
o
نتایج تست HTTPS
o
Certificate information
مرحله 8: خودکارسازی با Ansible
8.1 طراحی Automation
الزامات :
قبل از نوشتن playbooks ، طراحی کنید :
1
) چه task هایی باید automate شوند؟
2
) چه order باید داشته باشند؟
3
) چه variables نیاز است ؟
4
) چه handlers نیاز است ؟
5
) چه templates نیاز است؟
Hints:
•
Deployment process را break down کنی د
•
Dependencies را شناسایی کنی د
•
Error handling را در نظر بگیری د
8.1 Playbook برای Application Deployment
الزامات :
یک playbook بنویسید که :
18 | P a g e
1
Application directory ) را ایجاد کن د
2
) فایلهای پروژه را کپی کند:
o
Dockerfile
o
docker-compose.yml
o
Application code
1
) Docker images را build کن د
2
) Containers را run کن د
3
) Status را verify کن د
Hints:
•
از copy module برای فایلها استفاده کنی د
•
از docker_compose module برای Docker operations استفاده کنی د
•
از wait_for برای wait کردن استفاده کنی د
•
از register و debug برای verification استفاده کنی د
خروجی مورد نیاز :
•
فایل 08_ansible_automation/deploy_app.yml
•
فایل 08_ansible_automation/app_vars.yml در صورت نیا ز
8.2 Playbook برای Nginx Configuration
الزامات :
یک playbook بنویسید که :
1
) SSL directory را ایجاد کن د
2
) SSL certificate را generate کن د
3
) Nginx configuration template را deploy کن د
4
) Site را enable کن د
5
) Default site را disable کن د
19 | P a g e
6
Nginx ) را reload کن د
Hints:
•
از openssl_certificate module استفاده کنی د
•
از template module برای configuration استفاده کنی د
•
از file module برای symbolic links استفاده کنی د
•
از handlers برای reload استفاده کنی د
خروجی مورد نیاز :
•
فایل 08_ansible_automation/deploy_nginx.yml
•
فایل 08_ansible_automation/templates/nginx.conf.j2
•
فایل 08_ansible_automation/nginx_vars.yml در صورت نیا ز
8.4 ایجاد Main Playbook
الزامات :
یک main playbook ایجاد کنید که :
1
) تمام playbooks را import کن د
2
) Order صحیح را حفظ کن د
3
) Reusable باش د
Hints:
•
از import_playbook استفاده کنی د
•
از site.yml یا main.yml استفاده کنی د
خروجی مورد نیاز :
•
فایل 08_ansible_automation/site.yml
20 | P a g e
8.5 اجرا و تس ت
الزامات :
1
) Playbooks را اجرا کنی د
2
) Output را بررسی کنی د
3
) Application را verify کنی د
4
) اگر مشکلی بود، رفع کنی د
Hints:
•
از --check برای dry-run استفاده کنی د
•
از -v برای verbose output استفاده کنی د
•
از --diff برای مشاهده تغییرات استفاده کنی د
خروجی مورد نیاز :
•
فایل 08_ansible_automation/playbook_output.txt شامل خروجی اجرا
•
فایل 08_ansible_automation/verification.txt شامل نتایج verification
مرحله 9: مستندسازی
9.1 README.md
الزامات :
یک README.md کامل بنویسید که شامل:
1
) توضیح پروژ ه
2
) Prerequisites
3
) Installation instructions
4
) Usage instructions
21 | P a g e
5
Project structure )
6
) Configuration
7
) Troubleshooting
خروجی مورد نیاز :
•
فایل README.md در root پروژ ه
9.2 Architecture Documentation
الزامات :
یک document بنویسید که :
1
) Architecture را توضیح ده د
2
) Components را معرفی کن د
3
) Flow را نشان ده د
4
) Diagrams داشته باش د
Hints:
•
از text-based diagrams استفاده کنی د
•
از ASCII art استفاده کنی د
•
Flow را step-by-step نشان دهی د
خروجی مورد نیاز :
•
فایل 09_documentation/architecture.md
9.3 Deployment Guide
الزامات :
22 | P a g e
یک deployment guide بنویسید که:
1
) Step-by-step instructions داشته باش د
2
) Commands را شامل شو د
3
) Expected outputs را نشان ده د
4
) Common issues را cover کن د
خروجی مورد نیاز :
•
فایل 09_documentation/deployment_guide.md
9.4 Troubleshooting Guide
الزامات :
یک troubleshooting guide بنویسید که :
1
) مشکلات رایج را لیست کن د
2
) علت هر مشکل را توضیح ده د
3
) راهحلها را ارائه ده د
خروجی مورد نیاز :
•
فایل 09_documentation/troubleshooting.md
مرحله 10 : تحویل نهایی
10.1 Git Repository
الزامات :
1
) Git repository initialize کنی د
23 | P a g e
2
( تمام فای لها را add کنی د
3
) Meaningful commits انجام دهی د
4
) Repository را به GitHub/GitLab push کنی د
Hints:
•
از .gitignore استفاده کنی د
•
از meaningful commit messages استفاده کنی د
•
از branching strategy استفاده کنی د
خروجی مورد نیاز :
•
Git repository با تمام commits
•
فایل 10_delivery/git_history.txt شامل git log --oneline –graph
10.2 Project Summary
الزامات :
یک summary بنویسید که شامل:
1
) Challenges مواجه شد ه
2
) Solutions پیاد هسازی شد ه
3
) Lessons learned
4
) Improvements پیشنهادی
خروجی مورد نیاز :
•
فایل 10_delivery/project_summary.md
10.3 Final Structure
الزامات :
24 | P a g e
ساختار نهایی پروژه را document کنید .
خروجی مورد نیاز :
•
فایل 10_delivery/final_structure.txt شامل tree یا find output
10.4 Team Contribution
الزامات :
Contribution هر عضو تیم را document کنید.
خروجی مورد نیاز :
•
فایل 10_delivery/team_contribution.md شامل:
o
تقسیم کا ر
o
Contribution هر عض و
o
Challenges هر عض و
نکات مهم
کار تیم ی
•
تقسیم کار را به صورت منطقی انجام دهی د
•
یک نفر روی Docker و دیگری روی Ansible کار کن د
•
Code review انجام دهی د
•
Regular commits انجام دهی د
Testing
•
هر مرحله را قبل از ادامه تست کنی د
•
از logs برای debugging استفاده کنی د
25 | P a g e
•
از dry-run برای Ansible استفاده کنی د
Security
•
Passwords را در variables file قرار دهی د
•
از .gitignore برای فای لهای حساس استفاده کنی د
•
SSL certificates را secure نگه داری د
Best Practices
•
Code را clean و readable نگه داری د
•
Comments را meaningful بنویسی د
•
Documentation را به روز نگه داری د
منابع مفید
●
Docker Documentation: https://docs.docker.com/
●
Docker Compose Documentation: https://docs.docker.com/compose/
●
Ansible Documentation: https://docs.ansible.com/
●
Nginx Documentation: https://nginx.org/en/docs/
●
OpenSSL Documentation: https://www.openssl.org/docs/
مشکلات رای ج
مشکل: Docker build fails
چه باید کرد:
•
Logs را بررسی کنی د
•
Dockerfile syntax را check کنی د
•
Dependencies را verify کنی د
•
Base image را بررسی کنی د
مشکل: Ansible connection fails
26 | P a g e
چه باید کرد:
•
SSH connection را test کنی د
•
Inventory را بررسی کنی د
•
Permissions را check کنی د
•
Python interpreter را verify کنی د
مشکل: Nginx 502 Bad Gateway
چه باید کرد:
•
Container status را check کنی د
•
Port mapping را verify کنی د
•
Proxy configuration را بررسی کنی د
•
Logs را check کنی د
مشکل: SSL certificate errors
چه باید کرد:
•
Certificate path را verify کنی د
•
Permissions را check کنی د
•
Certificate validity را بررسی کنی د
•
Nginx configuration را test کنی د
موفق باشید! 🚀 این پروژه فرص ی ت عالی برای به کارگ ریی تمام مهار تهای یادگرفته شده است. از آن لذت ب ریید و به ی یین کار را انجام
دهید!

# AUDIT_REPORT
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


