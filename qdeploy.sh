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

export HOST_IP=$(cat ~/.qnet.host.v4)
export HOST_IPv6=$(cat ~/.qnet.host.v6)

# Create volumes for config and data
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
    server_name z2m.local;

    location / {
        proxy_pass http://zigbee2mqtt:8080;
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
    server_name pihole.local;

    location / {
        proxy_pass http://pihole:80;
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

server {
    listen 80;
    server_name garage.local;

    location / {
        proxy_pass http://garage:20001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

server {
    listen 20000;
    server_name garage.local;

    location /ws {
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
  clock:
    image: rqure/clock:latest
    restart: always
    environment:
      - Q_IN_DOCKER=true
  audio-player:
    image: rqure/audio-player:latest
    restart: always
    environment:
      - Q_IN_DOCKER=true
      - GOOGLE_APPLICATION_CREDENTIALS=/google/creds.json
    volumes:
      - ./volumes/google:/google
  prayer:
    image: rqure/adhan:latest
    restart: always
    environment:
      - ALERTS=TTS,EMAILS
      - Q_IN_DOCKER=true
  qsm:
    image: rqure/qsm:latest
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - Q_IN_DOCKER=true
    resources:
      limits:
        memory: 50M
  dmm:
    image: rqure/dmm:v1.0.0
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
  mosquitto:
    image: rqure/mosquitto:v1.0.0
    restart: always
  zigbee2mqtt:
    image: rqure/zigbee2mqtt:v1.1.0
    restart: always
    volumes:
      - /run/udev:/run/udev:ro
      - /dev/ttyUSB0:/dev/ttyACM0
      - ./volumes/qzigbee2mqtt:/app/data
  mqttgateway:
    image: rqure/mqttgateway:latest
    restart: always
    environment:
      - Q_IN_DOCKER=true
  garage:
    image: rqure/garage:latest
    restart: always
    environment:
      - ALERTS=TTS,EMAILS
      - Q_IN_DOCKER=true
  webgateway:
    image: rqure/webgateway:latest
    restart: always
    environment:
      - Q_IN_DOCKER=true
  alert:
    image: rqure/alert:latest
    restart: always
    environment:
      - Q_IN_DOCKER=true
  smtp:
    image: rqure/smtp:latest
    restart: always
    environment:
      - QDB_EMAIL_ADDRESS=${QDB_EMAIL_ADDRESS}
      - QDB_EMAIL_PASSWORD=${QDB_EMAIL_PASSWORD}
      - QDB_EMAIL_HOST=${QDB_EMAIL_HOST}
      - QDB_EMAIL_PORT=${QDB_EMAIL_PORT}
      - Q_IN_DOCKER=true
  duckdns:
    image: lscr.io/linuxserver/duckdns:latest
    restart: always
    volumes:
      - ./volumes/duckdns:/config
    environment:
      - SUBDOMAINS=${DUCKDNS_SUBDOMAINS}
      - TOKEN=${DUCKDNS_TOKEN}
  wireguard:
    image: ghcr.io/wg-easy/wg-easy
    restart: always
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    volumes:
      - ./volumes/wireguard:/etc/wireguard
    environment:
      - WG_HOST=${WIREGUARD_SERVERURL} # eth interface can be determined by running 'ip route get 8.8.8.8' in the wg container
      - WG_POST_UP=iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      - WG_POST_DOWN=iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
    ports:
      - 51820:51820/udp
      - 51821:51821/tcp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
  dozzle:
    image: amir20/dozzle:latest
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
  pihole:
    image: pihole/pihole:latest
    restart: always
    environment:
      TZ: 'America/Edmonton'
      WEBPASSWORD: 'rqure'
    ports:
      - "${HOST_IP}:53:53/tcp"
      - "${HOST_IP}:53:53/udp"
      - "[${HOST_IPv6}]:53:53/tcp"
      - "[${HOST_IPv6}]:53:53/udp"
    volumes:
      - './volumes/qpihole/etc-pihole/:/etc/pihole/'
      - './volumes/qpihole/etc-dnsmasq.d/:/etc/dnsmasq.d/'
  nginx:
    image: nginx:latest
    ports:
      - "80:80"
      - "20000:20000"
    volumes:
      - ./volumes/qnginx/conf.d:/etc/nginx/conf.d
      - ./volumes/qnginx/nginx.conf:/etc/nginx/nginx.conf
    restart: always
    depends_on:
      - garage
      - webgateway
      - dozzle
      - pihole
      - zigbee2mqtt
EOF

docker compose up -d --force-recreate
