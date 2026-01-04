#!/bin/bash
# —— SD CARD BACKUP TO SMB (FINAL VERSION with automatic PV detection) ——
# Supports: --raw, -h / --help

set -e

# ------------------------------
# Defaults
# ------------------------------
INI_FILE="$HOME/Oppleo/src/nl/oppleo/config/oppleo.ini"
MOUNT_POINT="/mnt/backup"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M)
RAW_MODE=0

# ------------------------------
# Help function
# ------------------------------
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --raw       Create raw .img backup (no gzip compression)."
    echo "              Note: pv is automatically ignored in raw mode."
    echo "  -h, --help  Show this help screen."
    echo ""
    echo "Other features:"
    echo "  • If gzip compression is used, the script automatically uses"
    echo "    'pv' for a progress bar if it is installed on the system."
    echo "  • Automatically detects the SD card and mounts the SMB share"
    echo "    using credentials from the PostgreSQL database."
    exit 0
}

# ------------------------------
# Parse command line options
# ------------------------------
while [ "$#" -gt 0 ]; do
    case "$1" in
        --raw) RAW_MODE=1 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
    shift
done

# ------------------------------
# Detect if pv is installed
# ------------------------------
if command -v pv >/dev/null 2>&1; then
    USE_PV=1
else
    USE_PV=0
fi

# Warn if raw mode disables pv
if [ $RAW_MODE -eq 1 ] && [ $USE_PV -eq 1 ]; then
    echo "⚠️ Raw mode enabled: pv will not be used (raw backups bypass compression)"
    USE_PV=0
fi

# ------------------------------
# Cleanup function
# ------------------------------
cleanup() {
    sudo umount "$MOUNT_POINT" 2>/dev/null || true
    sudo rmdir "$MOUNT_POINT" 2>/dev/null || true
    sudo rm -f "/root/.smbcredentials_$TIMESTAMP"
}
trap cleanup EXIT

echo "=== Backup started at $TIMESTAMP ==="

# ------------------------------
# 1️⃣ Read database_url from opleo.ini
# ------------------------------
DB_URL=$(grep '^database_url' "$INI_FILE" | cut -d= -f2- | tr -d ' ')
if [ -z "$DB_URL" ]; then
    echo "ERROR: database_url not found in $INI_FILE"
    exit 1
fi

DB_URL_NO_PROTO=${DB_URL#postgresql://}
DB_USER=$(echo "$DB_URL_NO_PROTO" | cut -d':' -f1)
DB_PASS=$(echo "$DB_URL_NO_PROTO" | cut -d':' -f2 | cut -d'@' -f1)
DB_HOST=$(echo "$DB_URL_NO_PROTO" | cut -d'@' -f2 | cut -d':' -f1)
DB_PORT=$(echo "$DB_URL_NO_PROTO" | cut -d':' -f3 | cut -d'/' -f1)
DB_NAME=$(echo "$DB_URL_NO_PROTO" | cut -d'/' -f2)
DB_PORT=${DB_PORT:-5432}

# ------------------------------
# 2️⃣ Query PostgreSQL for SMB credentials safely
# ------------------------------
SMB_ROW=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -At -F $'\t' <<EOF
SELECT
    smb_backup_username,
    smb_backup_password,
    smb_backup_servername_or_ip_address,
    smb_backup_service_name,
    smb_backup_remote_path
FROM charger_config
LIMIT 1;
EOF
)

SMB_USER=$(echo "$SMB_ROW" | cut -f1)
SMB_PASS=$(echo "$SMB_ROW" | cut -f2)
SMB_SERVER=$(echo "$SMB_ROW" | cut -f3)
SMB_SERVICE=$(echo "$SMB_ROW" | cut -f4)
SMB_PATH=$(echo "$SMB_ROW" | cut -f5)

if [ -z "$SMB_USER" ] || [ -z "$SMB_SERVER" ]; then
    echo "ERROR: SMB configuration incomplete in database"
    exit 1
fi

SMB_PATH=$(echo "$SMB_PATH" | sed 's#^/*##;s#/*$##')
SMB_SHARE="//$SMB_SERVER/$SMB_SERVICE/$SMB_PATH"

echo "Using SMB share: $SMB_SHARE"

# ------------------------------
# 3️⃣ Mount SMB share
# ------------------------------
sudo mkdir -p "$MOUNT_POINT"

CRED_FILE="/root/.smbcredentials_$TIMESTAMP"
echo "username=$SMB_USER" | sudo tee "$CRED_FILE" >/dev/null
echo "password=$SMB_PASS" | sudo tee -a "$CRED_FILE" >/dev/null

sudo mount -t cifs "$SMB_SHARE" "$MOUNT_POINT" \
  -o credentials="$CRED_FILE",vers=3.1.1,iocharset=utf8

# ------------------------------
# 4️⃣ Detect SD card device
# ------------------------------
ROOT_PART=$(findmnt -n -o SOURCE /)
SD_DISK=$(lsblk -no PKNAME "$ROOT_PART")

if [ -z "$SD_DISK" ]; then
    echo "ERROR: Unable to detect SD card disk"
    exit 1
fi

SD_DEV="/dev/$SD_DISK"
echo "Detected SD card: $SD_DEV"

# ------------------------------
# 5️⃣ Prepare backup filenames (overwrite-safe)
# ------------------------------
BASE="LaadpaalNoord_sdcard_backup_$TIMESTAMP"
if [ $RAW_MODE -eq 1 ]; then
    OUT="$MOUNT_POINT/$BASE.img"
else
    OUT="$MOUNT_POINT/$BASE.img.gz"
fi
LOG="$MOUNT_POINT/$BASE.log"

i=1
while [ -e "$OUT" ]; do
    if [ $RAW_MODE -eq 1 ]; then
        OUT="$MOUNT_POINT/${BASE}_$i.img"
    else
        OUT="$MOUNT_POINT/${BASE}_$i.img.gz"
    fi
    LOG="$MOUNT_POINT/${BASE}_$i.log"
    i=$((i + 1))
done

# ------------------------------
# 6️⃣ Run backup
# ------------------------------
echo "Flushing filesystem buffers..."
sudo sync

echo "Starting backup → $OUT"

if [ $RAW_MODE -eq 1 ]; then
    sudo sh -c "dd if='$SD_DEV' bs=4M status=progress conv=fsync > '$OUT'"
else
    if [ $USE_PV -eq 1 ]; then
        echo "Using pv for progress bar"
        sudo sh -c "pv -tpreb -B 4M '$SD_DEV' | dd bs=4M conv=fsync | gzip -1 > '$OUT'"
    else
        sudo sh -c "dd if='$SD_DEV' bs=4M status=progress conv=fsync | gzip -1 > '$OUT'"
    fi
fi

# ------------------------------
# 7️⃣ Write log
# ------------------------------
{
    echo "$TIMESTAMP Backup completed successfully"
    echo "Device : $SD_DEV"
    echo "Image  : $OUT"
    echo "SMB    : $SMB_SHARE"
    echo "Compression: $( [ $RAW_MODE -eq 1 ] && echo 'raw' || echo 'gzip -1' )"
    echo "PV used: $( [ $USE_PV -eq 1 ] && echo 'yes' || echo 'no' )"
} | sudo tee "$LOG" >/dev/null

echo "=== Backup finished successfully ==="
