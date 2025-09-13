#!/usr/bin/env bash
# Ubuntu mirror sync script for 22.04 (jammy) and 24.04 (noble)
# Works with /srv/mirror
# Includes error handling and logging
# Author: trident setup

set -euo pipefail

# ----------------------------
# Configuration
# ----------------------------
BASE_ROOT="/srv/mirror/ubuntu"
ARCHES="amd64"
#SECTIONS="main,restricted,universe,multiverse"
SECTIONS="main"
EXTRA="--rsync-extra=trace,docs,indices,udebs"
METHOD="rsync"

# rsync options
RSYNC_BATCH=300

# Upstream mirrors
ARCHIVE_HOST="archive.ubuntu.com"
SECURITY_HOST="security.ubuntu.com"
ROOT_PATH="ubuntu"

# Suites
JAMMY="jammy jammy-updates jammy-backports"
JAMMY_SECURITY="jammy-security"
NOBLE="noble noble-updates noble-backports"
NOBLE_SECURITY="noble-security"

# Logging
LOG_FILE="/var/log/ubuntu-mirror.log"

# ----------------------------
# Error handling
# ----------------------------
error_exit() {
    echo "[$(date)] ERROR: $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

trap 'error_exit "Unexpected failure on line $LINENO."' ERR

# ----------------------------
# Ensure mirror directories exist
# ----------------------------
mkdir -p "$BASE_ROOT/jammy/archive" "$BASE_ROOT/jammy/security"
mkdir -p "$BASE_ROOT/noble/archive" "$BASE_ROOT/noble/security"
chown -R root:root "$BASE_ROOT"
chmod -R 755 "$BASE_ROOT"

# ----------------------------
# Configure custom GPG keyring for Ubuntu mirror
# ----------------------------
export GNUPGHOME="/srv/mirror/ubuntu/mirrorkeyring"

if [ ! -f "$GNUPGHOME/trustedkeys.kbx" ]; then
    mkdir -p "$GNUPGHOME"
    gpg --no-default-keyring \
        --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg \
        --export | gpg --no-default-keyring --keyring "$GNUPGHOME/trustedkeys.kbx" --import
    chmod 700 "$GNUPGHOME"
    chown -R root:root "$GNUPGHOME"
    echo "[$(date)] GPG keyring initialized in $GNUPGHOME" | tee -a "$LOG_FILE"
fi

# ----------------------------
# Common flags for debmirror
# ----------------------------
COMMON_FLAGS="--arch=$ARCHES --section=$SECTIONS --no-source \
--method=$METHOD --root=$ROOT_PATH $EXTRA --progress --nocleanup \
--keyring=$GNUPGHOME/trustedkeys.kbx --diff=use --rsync-batch=$RSYNC_BATCH"

# ----------------------------
# Lock function
# ----------------------------
lock_file() {
    local lockfile="$1"
    if [ -e "$lockfile" ]; then
        echo "[$(date)] Another instance is running ($lockfile). Exiting." | tee -a "$LOG_FILE"
        exit 1
    fi
    touch "$lockfile"
    trap "rm -f '$lockfile'" EXIT
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
            echo "[$(date)] Starting mirror: $suite (attempt $attempts/$max_attempts)" | tee -a "$LOG_FILE"

            if debmirror $COMMON_FLAGS --host="$host" --dist="$suite" "$target_dir" 2>&1 | tee -a "$LOG_FILE"; then
                echo "[$(date)] Finished mirror: $suite (success)" | tee -a "$LOG_FILE"
                success=1
                break
            else
                echo "[$(date)] WARNING: Mirror failed for $suite on attempt $attempts" | tee -a "$LOG_FILE"
                sleep 60
            fi
        done

        if [ $success -eq 0 ]; then
            error_exit "Mirror failed for $suite after $max_attempts attempts"
        fi
    done
}

# ----------------------------
# Run mirrors
# ----------------------------
mirror_suite "$JAMMY" "$ARCHIVE_HOST" "$BASE_ROOT/jammy/archive" &
mirror_suite "$JAMMY_SECURITY" "$SECURITY_HOST" "$BASE_ROOT/jammy/security" &

mirror_suite "$NOBLE" "$ARCHIVE_HOST" "$BASE_ROOT/noble/archive" &
mirror_suite "$NOBLE_SECURITY" "$SECURITY_HOST" "$BASE_ROOT/noble/security" &

wait

echo "[$(date)] All mirrors completed successfully!" | tee -a "$LOG_FILE"
