# Set environment
if [ ! -f ~/.duckdns.subdomains ]; then
    touch ~/.duckdns.subdomains
fi

if [ ! -f ~/.duckdns.token ]; then
    touch ~/.duckdns.token
fi

if [ ! -f ~/.wireguard.serverurl ]; then
    touch ~/.wireguard.serverurl
fi

if [ ! -f ~/.smtp.email ]; then
    touch ~/.smtp.email
fi

if [ ! -f ~/.smtp.pwd ]; then
    touch ~/.smtp.pwd
fi

if [ ! -f ~/.smtp.host ]; then
    touch ~/.smtp.host
fi

if [ ! -f ~/.smtp.port ]; then
    touch ~/.smtp.port
fi

if [ ! -f ~/.google.app.creds ]; then
    touch ~/.google.app.creds
fi

export NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}')
if [ ! -f ~/.qnet.host.v4 ]; then
    export HOST_IP=$(ip -4 addr show dev $NETWORK_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | awk -F'/' '{print $1}')
    echo "$HOST_IP" > ~/.qnet.host.v4
fi

if [ ! -f ~/.qnet.host.v6 ]; then
    # Get the statically assigned ULA address
    export HOST_IPv6=$(ip -6 addr show dev $NETWORK_INTERFACE | grep 'inet6 fd00' | head -n 1 | awk '{print $2}' | cut -d'/' -f1)
    echo "$HOST_IPv6" > ~/.qnet.host.v6
fi

export DUCKDNS_SUBDOMAINS=$(cat ~/.duckdns.subdomains)
export DUCKDNS_TOKEN=$(cat ~/.duckdns.token)
export WIREGUARD_SERVERURL=$(cat ~/.wireguard.serverurl)

export QDB_EMAIL_ADDRESS=$(cat ~/.smtp.email)
export QDB_EMAIL_PASSWORD=$(cat ~/.smtp.pwd)
export QDB_EMAIL_HOST=$(cat ~/.smtp.host)
export QDB_EMAIL_PORT=$(cat ~/.smtp.port)

export GOOGLE_APPLICATION_CREDENTIALS=$(cat ~/.google.app.creds)

export HOST_IP=$(cat ~/.qnet.host.v4)
export HOST_IPv6=$(cat ~/.qnet.host.v6)

# Create volumes for config and data
mkdir -p volumes/google/
if [ ! -f volumes/google/creds.json ]; then
    cp ~/.google.app.creds volumes/google/creds.json
fi

mkdir -p volumes/duckdns/

mkdir -p volumes/wireguard/

mkdir -p volumes/qzigbee2mqtt/
if [ ! -f volumes/qzigbee2mqtt/configuration.yaml ]; then
    curl https://raw.githubusercontent.com/rqure/qzigbee2mqtt/main/configuration.yaml -o volumes/qzigbee2mqtt/configuration.yaml
fi

mkdir -p volumes/qredis/data/

mkdir -p volumes/qpihole/etc-dnsmasq.d/
mkdir -p volumes/qpihole/etc-pihole/
if [ ! -f volumes/qpihole/etc-pihole/custom.list ]; then
    echo "${HOST_IP} qserver.local" > volumes/qpihole/etc-pihole/custom.list
    echo "${HOST_IPv6} qserver.local" >> volumes/qpihole/etc-pihole/custom.list
fi

if [ ! -f volumes/qpihole/etc-dnsmasq.d/05-pihole-custom-cname.conf ]; then
    cat <<EOF > volumes/qpihole/etc-dnsmasq.d/05-pihole-custom-cname.conf
cname=logs.local,qserver.local
cname=garage.local,qserver.local
cname=z2m.local,qserver.local
cname=database.local,qserver.local
cname=pihole.local,qserver.local
EOF
fi

mkdir -p volumes/qnginx/conf.d/
if [ ! -f volumes/qnginx/nginx.conf ]; then
    cat <<EOF > volumes/qnginx/nginx.conf
user  nginx;
worker_processes  auto;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    types_hash_max_size 2048;

    client_max_body_size 1000M;

    include /etc/nginx/conf.d/*.conf;
}
EOF
fi

if [ ! -f volumes/qnginx/conf.d/default.conf ]; then
    cat <<EOF > volumes/qnginx/conf.d/default.conf
server {
    listen 80;

    location / {
        proxy_pass http://webgateway:20000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

server {
    listen 80;
    server_name logs.local;

    location / {
        proxy_pass http://dozzle:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

server {
    listen 80;
    server_name database.local;

    location / {
        proxy_pass http://webgateway:20000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

EOF
fi

cat <<EOF > docker-compose.yml
version: "3.3"
services:
  redis:
    image: redis:alpine
    restart: always
    volumes:
      - ./volumes/qredis/data:/data
    ports:
      - "6379:6379"
  clock:
    image: rqure/clock:v2.3.7
    restart: always
    environment:
      - Q_IN_DOCKER=true
  qsm:
    image: rqure/qsm:v0.1.8
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - Q_IN_DOCKER=true
  webgateway:
    image: rqure/webgateway:v0.1.9
    restart: always
    environment:
      - Q_IN_DOCKER=true
  audio-player:
    image: rqure/audio-player:v1.2.11
    restart: always
    environment:
      - Q_IN_DOCKER=true
      - GOOGLE_APPLICATION_CREDENTIALS=/google/creds.json
    volumes:
      - ./volumes/google:/google
  adhan:
    image: rqure/adhan:v2.3.3
    restart: always
    environment:
      - ALERTS=TTS
      - Q_IN_DOCKER=true
  alert:
    image: rqure/alert:v0.1.4
    restart: always
    environment:
      - Q_IN_DOCKER=true
  dozzle:
    image: amir20/dozzle:latest
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    ports:
      - "8080:8080"
  nginx:
    image: nginx:latest
    ports:
      - "80:80"
      - "20000:20000"
    volumes:
      - ./volumes/qnginx/conf.d:/etc/nginx/conf.d
      - ./volumes/qnginx/nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - webgateway
      - dozzle
EOF

docker compose up -d --force-recreate
