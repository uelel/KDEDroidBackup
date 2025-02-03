#!/bin/bash

ANDROID_USER="kdeconnect"
ANDROID_HOST="192.168.5.107"
ANDROID_PORT="1739"
ANDROID_DIR="/storage/emulated/0"
ANDROID_MOUNT="/media/other"
DEST_MOUNT=""
BACKUP_PREFIX="android-"
SSH_KEY="$HOME/.config/kdeconnect/privateKey.pem"

# Function to show usage
usage() {
  echo "Usage: $0 -d <destination_mount>"
  exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -d|--dest)
      DEST_MOUNT="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

# Ensure destination mount is provided
if [ -z "$DEST_MOUNT" ]; then
  echo "Error: Destination mount is required."
  usage
fi

# Check if the destination is mounted
echo "Checking if destination is mounted at $DEST_MOUNT..."
if ! mountpoint -q "$DEST_MOUNT"; then
  echo "Error: Destination is not mounted at $DEST_MOUNT. Please mount it before running this script."
  exit 1
fi

echo "Mounting the Android device..."
sshfs -o rw,nosuid,nodev,identityfile="$SSH_KEY",port="$ANDROID_PORT",uid=$(id -u),gid=$(id -g),allow_other "$ANDROID_USER@$ANDROID_HOST:$ANDROID_DIR" "$ANDROID_MOUNT"

# Check if the mount was successful
if [ $? -ne 0 ]; then
  echo "Error: Failed to mount the Android filesystem."
  exit 1
fi

# Find an existing backup folder starting with "android-" or create a new one
EXISTING_BACKUP_DIR=$(find "$DEST_MOUNT" -maxdepth 1 -type d -name "${BACKUP_PREFIX}*")
NEW_BACKUP_DIR="$DEST_MOUNT/${BACKUP_PREFIX}$(date +'%Y-%m-%d')"
if [ -n "$EXISTING_BACKUP_DIR" ]; then
  sudo mv "$EXISTING_BACKUP_DIR" "$NEW_BACKUP_DIR"
  echo "Renamed existing backup directory to: $NEW_BACKUP_DIR"
else
  sudo bash -c "mkdir -p '$NEW_BACKUP_DIR'"
  echo "No existing backup directory found. Created new backup directory: $NEW_BACKUP_DIR"
fi

echo "Syncing files from Android to backup folder..."
sudo rsync -ah --info=progress2 --ignore-errors --omit-dir-times --timeout=30 --verbose --update "$ANDROID_MOUNT/" "$NEW_BACKUP_DIR/"

# Verify the backup creation
if [ $? -eq 0 ]; then
  echo "Backup created successfully: $NEW_BACKUP_DIR"
else
  echo "Error: Failed to create the backup."
  echo "Unmounting the remote device..."
  fusermount -u "$ANDROID_MOUNT"
  exit 1
fi
