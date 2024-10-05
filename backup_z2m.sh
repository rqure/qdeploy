#!/bin/bash

# Dependency Install
# sudo -v ; curl https://rclone.org/install.sh | sudo bash

# Variables
DIRECTORY=volumes
TAR_FILENAME="backup_z2m_$(date +'%Y%m%d_%H%M%S').tar.gz"
TAR_FILEPATH="/tmp/$TAR_FILENAME"
GDRIVE_FOLDER_ID="backups/volumes"

# Create a tar.gz archive of the directory
tar -czvf "$TAR_FILEPATH" "$DIRECTORY"

# Check if tar succeeded
if [ $? -eq 0 ]; then
    echo "Successfully created tarball: $TAR_FILEPATH"
else
    echo "Error creating tarball"
    exit 1
fi

# Upload to Google Drive using rclone
rclone copy "$TAR_FILEPATH" "gdrive:$GDRIVE_FOLDER_ID"

# Check if upload succeeded
if [ $? -eq 0 ]; then
    echo "Successfully uploaded $TAR_FILENAME to Google Drive"
else
    echo "Error uploading to Google Drive"
    exit 1
fi
