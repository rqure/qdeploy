VERSION=v0.0.2

# # Download from release page
wget -O snapshot.tar.gz https://github.com/rqure/qsnapshot/releases/download/$VERSION/snapshot.tar.gz

# # Extract to qtmp/snapshot.json
tar -xzvf snapshot.tar.gz

# Restore snapshot
ID=$(curl -s localhost/make-client-id | jq -r '.header.id')
SNAPSHOT=$(cat tmp/snapshot.json | jq ".header.id = \"$ID\"")
echo $SNAPSHOT > tmp/snapshot.json
curl http://localhost/api -d @./tmp/snapshot.json

# Cleanup
rm -rf tmp

echo