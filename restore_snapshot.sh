VERSION=v0.0.3

# # Download from release page
wget -O snapshot.tar.gz https://github.com/rqure/qsnapshot/releases/download/$VERSION/snapshot.tar.gz

# # Extract to qtmp/snapshot.json
tar -xzvf snapshot.tar.gz

# Restore snapshot
ID=$(curl -s "localhost/make-client-id?clientTimeout=60" | jq -r '.header.id')
SNAPSHOT=$(cat tmp/snapshot.json | jq ".header.id = \"$ID\"")
echo $SNAPSHOT > tmp/snapshot.json
curl "http://localhost/api?requestTimeout=60" -d @./tmp/snapshot.json

# Cleanup
rm -rf tmp snapshot.tar.gz

echo