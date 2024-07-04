wget -O /tmp/snapshot.json https://github.com/rqure/qsnapshot/releases/download/v0.0.0/snapshot.json
curl localhost:20000/api -d @/tmp/snapshot.json
rm -f /tmp/snapshot.json
