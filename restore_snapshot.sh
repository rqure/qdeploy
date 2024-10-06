VERSION=0.0.2

# Download from release page
wget -O /tmp/snapshot.tar.gz https://github.com/rqure/qsnapshot/releases/download/$VERSION/snapshot.tar.gz

# Extract to /tmp/snapshot.json
tar -xvf /tmp/snapshot.tar.gz -C /tmp snapshot.json

# Restore snapshot
curl http://localhost/api -d @/tmp/snapshot.json

# Cleanup
rm -f /tmp/snapshot.json /tmp/snapshot.tar.gz
