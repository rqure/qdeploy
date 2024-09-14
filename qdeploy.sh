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

export NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}')
if [ ! -f ~/.qnet.host.v4 ]; then
    export HOST_IP=$(ip -4 addr show dev $NETWORK_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | awk -F'/' '{print $1}')
    echo "$HOST_IP" > ~/.qnet.host.v4
fi

if [ ! -f ~/.qnet.host.v6 ]; then
    export HOST_IPv6=$(ip -6 addr show dev $NETWORK_INTERFACE scope link | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d')
    echo "$HOST_IPv6" > ~/.qnet.host.v6
fi

if [ ! -f ~/.qnet.gateway.v4 ]; then
    export GATEWAY=$(ip route | grep default | awk '{print $3}')
    echo "$GATEWAY" > ~/.qnet.gateway.v4
fi

if [ ! -f ~/.qnet.gateway.v6 ]; then
    export GATEWAYv6=$(ip -6 route | grep default | awk '{print $3}')
    echo "$GATEWAYv6" > ~/.qnet.gateway.v6
fi

if [ ! -f ~/.qnet.subnet.v4 ]; then
    echo "192.168.1.0/24" > ~/.qnet.subnet.v4
fi

if [ ! -f ~/.qnet.subnet.v6 ]; then
    echo "fe80::/10" > ~/.qnet.subnet.v6
fi

if [ ! -f ~/.qnet.pihole.v4 ]; then
    echo "192.168.1.10" > ~/.qnet.pihole.v4
fi

if [ ! -f ~/.qnet.pihole.v6 ]; then
    echo "fe80::10" > ~/.qnet.pihole.v6
fi

export DUCKDNS_SUBDOMAINS=$(cat ~/.duckdns.subdomains)
export DUCKDNS_TOKEN=$(cat ~/.duckdns.token)
export WIREGUARD_SERVERURL=$(cat ~/.wireguard.serverurl)

export HOST_IP=$(cat ~/.qnet.host.v4)
export HOST_IPv6=$(cat ~/.qnet.host.v6)
export GATEWAY=$(cat ~/.qnet.gateway.v4)
export GATEWAYv6=$(cat ~/.qnet.gateway.v6)
export SUBNET=$(cat ~/.qnet.subnet.v4)
export SUBNETv6=$(cat ~/.qnet.subnet.v6)
export PIHOLEv4=$(cat ~/.qnet.pihole.v4)
export PIHOLEv6=$(cat ~/.qnet.pihole.v6)

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
cname=pi.hole,qserver.local
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
    image: rqure/clock:v2.2.3
    restart: always
  audio-player:
    image: rqure/audio-player:v1.2.5
    restart: always
  prayer:
    image: rqure/adhan:v2.2.4
    restart: always
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
    image: rqure/mqttgateway:v1.2.3
    restart: always
    environment:
      - QMQ_LOG_LEVEL=0
  garage:
    image: rqure/garage:v1.2.4
    restart: always
  webgateway:
    image: rqure/webgateway:v0.0.8
    restart: always
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
      - "${PIHOLEv4}:53:53/tcp"
      - "${PIHOLEv4}:53:53/udp"
      - "[${PIHOLEv6}]:53:53/tcp"
      - "[${PIHOLEv6}]:53:53/udp"
    volumes:
      - './volumes/qpihole/etc-pihole/:/etc/pihole/'
      - './volumes/qpihole/etc-dnsmasq.d/:/etc/dnsmasq.d/'
    networks:
      qnet:
        ipv4_address: ${PIHOLEv4}
        ipv6_address: ${PIHOLEv6}
  nginx:
    image: nginx:latest
    ports:
      - "80:80"
      - "20000:20000"
    volumes:
      - ./volumes/qnginx/conf.d:/etc/nginx/conf.d
      - ./volumes/qnginx/nginx.conf:/etc/nginx/nginx.conf
networks:
  qnet:
    enable_ipv6: true
    driver: macvlan
    driver_opts:
      parent: ${NETWORK_INTERFACE}
    ipam:
      config:
        - subnet: ${SUBNET}
          gateway: ${GATEWAY}
        - subnet: ${SUBNETv6}
          gateway: ${GATEWAYv6}
EOF

docker compose up -d
