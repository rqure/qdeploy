#!/bin/bash

# Dependency Install
# sudo apt install jq
# sudo -v ; curl https://rclone.org/install.sh | sudo bash

# Variables
DIRECTORY=/tmp/snapshot.json
TAR_FILENAME="backup_snapshot_$(date +'%Y%m%d_%H%M%S').tar.gz"
TAR_FILEPATH="/tmp/$TAR_FILENAME"
GDRIVE_FOLDER_ID="backups/volumes"

# Make a backup
ID=$(curl -s localhost/db/make-client-id | jq -r '.header.id')
curl localhost/db/api -d "{\"header\":{\"id\":\"$ID\",\"timestamp\":\"2024-07-04T22:37:18.544393318Z\"},\"payload\":{\"@type\":\"type.googleapis.com/qdb.WebConfigCreateSnapshotRequest\"}}" | jq '.payload |= (del(.status) | .["@type"] = "type.googleapis.com/qdb.WebConfigRestoreSnapshotRequest")' > $DIRECTORY

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

# Cleanup
rm -f /tmp/snapshot.json /tmp/snapshot.tar.gz