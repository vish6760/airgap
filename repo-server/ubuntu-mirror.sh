#!/usr/bin/env bash
# Ubuntu mirror sync script for 22.04 (jammy) and 24.04 (noble)
# Improved version with logging helpers, stale lock cleanup, and parallel-safe execution
# Author: Trident Setup

set -euo pipefail

# ----------------------------
# Logging helpers
# ----------------------------
log_step()   { echo -e "[$(date)] → $*"; }
log_done()   { echo -e "[$(date)] ✔ $*"; }
log_skip()   { echo -e "[$(date)] ⚠ $*"; }
log_error()  { echo -e "[$(date)] ✘ $*" >&2; }

# ----------------------------
# Configuration
# ----------------------------
BASE_ROOT="/srv/mirror/ubuntu"
ARCHES="amd64"
SECTIONS="main,universe"            # change to main, restricted, universe if needed
EXTRA="--rsync-extra=trace,docs,indices,udebs"
METHOD="rsync"
RSYNC_BATCH=2400

ARCHIVE_HOST="archive.ubuntu.com"
SECURITY_HOST="security.ubuntu.com"
ROOT_PATH="ubuntu"

JAMMY="jammy jammy-updates jammy-backports"
JAMMY_SECURITY="jammy-security"
#NOBLE="noble noble-updates noble-backports"
#NOBLE_SECURITY="noble-security"

LOG_FILE="/var/log/ubuntu-mirror.log"

# ----------------------------
# Error handling
# ----------------------------
error_exit() {
    log_error "$1" | tee -a "$LOG_FILE"
    exit 1
}

trap 'error_exit "Unexpected failure on line $LINENO."' ERR

# ----------------------------
# Global cleanup trap
# ----------------------------
cleanup() {
    log_skip "Stopping all mirrors..."
    kill -TERM ${pids[*]} 2>/dev/null || true
    find "$BASE_ROOT" -name ".mirror.lock" -delete
}
trap cleanup INT TERM EXIT

# ----------------------------
# Ensure mirror directories exist
# ----------------------------
mkdir -p "$BASE_ROOT/jammy/archive" "$BASE_ROOT/jammy/security"
#mkdir -p "$BASE_ROOT/noble/archive" "$BASE_ROOT/noble/security"
chown -R root:root "$BASE_ROOT"
chmod -R 755 "$BASE_ROOT"

# ----------------------------
# Configure GPG keyring
# ----------------------------
export GNUPGHOME="$BASE_ROOT/mirrorkeyring"
if [ ! -f "$GNUPGHOME/trustedkeys.kbx" ]; then
    mkdir -p "$GNUPGHOME"
    gpg --no-default-keyring \
        --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg \
        --export | gpg --no-default-keyring --keyring "$GNUPGHOME/trustedkeys.kbx" --import
    chmod 700 "$GNUPGHOME"
    chown -R root:root "$GNUPGHOME"
    log_done "GPG keyring initialized in $GNUPGHOME"
fi

# ----------------------------
# Dependency check
# ----------------------------
check_and_install_deps() {
    local pkgs=("debmirror" "rsync" "gnupg" "apt-transport-https" "ca-certificates")

    for pkg in "${pkgs[@]}"; do
        if ! command -v "${pkg%% *}" >/dev/null 2>&1; then
            log_skip "Missing dependency: $pkg – installing..."
            if command -v apt-get >/dev/null 2>&1; then
                DEBIAN_FRONTEND=noninteractive apt-get update -qq
                DEBIAN_FRONTEND=noninteractive apt-get install -y $pkg
            else
                log_error "Cannot install $pkg automatically (apt-get not found)."
                exit 1
            fi
        else
            log_done "Dependency already installed: $pkg"
        fi
    done
}

check_and_install_deps

# ----------------------------
# Common debmirror flags
# ----------------------------
COMMON_FLAGS="--arch=$ARCHES --section=$SECTIONS --no-source \
--method=$METHOD --root=$ROOT_PATH $EXTRA --progress --nocleanup \
--keyring=$GNUPGHOME/trustedkeys.kbx --diff=use --rsync-batch=$RSYNC_BATCH \
--exclude-deb-section=debug"

# ----------------------------
# Lock function with stale lock handling
# ----------------------------
lock_file() {
    local lockfile="$1"
    if [ -e "$lockfile" ]; then
        oldpid=$(cat "$lockfile" 2>/dev/null || echo "")
        if [ -n "$oldpid" ] && ! ps -p "$oldpid" > /dev/null 2>&1; then
            log_skip "Removing stale lock $lockfile (PID $oldpid)"
            rm -f "$lockfile"
        else
            log_skip "Another instance is running ($lockfile). Exiting."
            exit 1
        fi
    fi
    echo $$ > "$lockfile"
}

# ----------------------------
# Mirror function with retry
# ----------------------------
mirror_suite() {
    local suite_list=$1
    local host=$2
    local target_dir=$3
    local lockfile="$target_dir/.mirror.lock"

    lock_file "$lockfile"

    for suite in $suite_list; do
        local attempts=0
        local max_attempts=3
        local success=0

        while [ $attempts -lt $max_attempts ]; do
            attempts=$((attempts+1))
            log_step "Starting mirror: $suite (attempt $attempts/$max_attempts)" | tee -a "$LOG_FILE"

            if debmirror $COMMON_FLAGS --host="$host" --dist="$suite" "$target_dir" 2>&1 | tee -a "$LOG_FILE"; then
                log_done "Finished mirror: $suite (success)" | tee -a "$LOG_FILE"
                success=1
                break
            else
                log_skip "Mirror failed for $suite on attempt $attempts" | tee -a "$LOG_FILE"
                sleep 60
            fi
        done

        if [ $success -eq 0 ]; then
            error_exit "Mirror failed for $suite after $max_attempts attempts"
        fi
    done

    rm -f "$lockfile"
    log_done "Released lock for $target_dir"
}

# ----------------------------
# Run mirrors in parallel safely
# ----------------------------
pids=()

mirror_suite "$JAMMY" "$ARCHIVE_HOST" "$BASE_ROOT/jammy/archive" & pids+=($!)
mirror_suite "$JAMMY_SECURITY" "$SECURITY_HOST" "$BASE_ROOT/jammy/security" & pids+=($!)
#mirror_suite "$NOBLE" "$ARCHIVE_HOST" "$BASE_ROOT/noble/archive" & pids+=($!)
#mirror_suite "$NOBLE_SECURITY" "$SECURITY_HOST" "$BASE_ROOT/noble/security" & pids+=($!)

# Wait for all background jobs
wait

log_done "All mirrors completed successfully!"
