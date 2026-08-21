#!/usr/bin/env bash
#
# deploy.sh - Deploy Vikunja stack on remote server using Docker Compose.
# Usage: ./deploy.sh
# Environment: SERVER (default: ubuntu@192.168.1.5), PROJECT_DIR (default: /opt/vikunja/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER="${SERVER:-ubuntu@192.168.1.5}"
PROJECT_DIR="${PROJECT_DIR:-/opt/vikunja/}"

OUT_DIR="${SCRIPT_DIR}"
mkdir -p "$OUT_DIR"

DEPLOY_LOG="${OUT_DIR}/deploy_log.txt"
STATUS_LOG="${OUT_DIR}/container_status.txt"
LOGS_LOG="${OUT_DIR}/container_logs.txt"

# Ask for sudo password (will be used with -S)
read -s -p "Enter sudo password for $SERVER: " SUDO_PASS
echo

# We'll run a remote script via ssh with a here-document.
# The entire script is sent to bash on the remote side.
# Password is passed as an environment variable.
# We use -t to force a pseudo-terminal (so sudo -S can read password from stdin).

run_remote_script() {
    # $1 = output file (locally)
    # $2 = a label for the log
    # The rest of arguments are commands to run remotely (as a single string)
    local outfile="$1"
    shift
    local label="$1"
    shift
    # The commands are passed as a single string in $*
    # We'll embed them in a here-document.
    ssh -t -o ConnectTimeout=10 "$SERVER" \
        "cd '$PROJECT_DIR' && SUDO_PASS='$SUDO_PASS' bash -s" \
        <<EOF > "$outfile" 2>&1
set -euo pipefail
echo "Connecting to $SERVER $label ..."
$*
EOF
}

# Define the commands to run on remote
collect_deploy() {
    cat <<'EOF'
echo "===== Deployment started at $(date) ====="
echo ">>> Building images..."
echo "$SUDO_PASS" | sudo -S docker compose build
echo ">>> Starting containers..."
echo "$SUDO_PASS" | sudo -S docker compose up -d
echo "===== Deployment finished at $(date) ====="
EOF
}

collect_status() {
    cat <<'EOF'
echo "===== Container status (docker-compose ps) ====="
echo "$SUDO_PASS" | sudo -S docker compose ps
EOF
}

collect_logs() {
    cat <<'EOF'
echo "===== Container logs (tail 1000) ====="
echo "$SUDO_PASS" | sudo -S docker compose logs --tail=1000
EOF
}

# Execute each part and save to respective files
run_remote_script "$DEPLOY_LOG" "for deployment" "$(collect_deploy)"
run_remote_script "$STATUS_LOG" "for status" "$(collect_status)"
run_remote_script "$LOGS_LOG" "for logs" "$(collect_logs)"

echo "Done. Output files:"
echo "  - $DEPLOY_LOG"
echo "  - $STATUS_LOG"
echo "  - $LOGS_LOG"