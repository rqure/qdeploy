# Set environment)
if [ ! -f ~/.duckdns.subdomains ]; then
    touch ~/.duckdns.subdomains
fi

if [ ! -f ~/.duckdns.token ]; then
    touch ~/.duckdns.token
fi

if [ ! -f ~/.wireguard.serverurl ]; then
    touch ~/.wireguard.serverurl
fi

export DUCKDNS_SUBDOMAINS=$(cat ~/.duckdns.subdomains)
export DUCKDNS_TOKEN=$(cat ~/.duckdns.token)
export WIREGUARD_SERVERURL=$(cat ~/.wireguard.serverurl)

# Create volumes for config and data
mkdir -p volumes/duckdns/

mkdir -p volumes/wireguard/

mkdir -p volumes/qzigbee2mqtt/
if [ ! -f volumes/qzigbee2mqtt/configuration.yaml ]; then
    curl https://raw.githubusercontent.com/rqure/qzigbee2mqtt/main/configuration.yaml -o volumes/qzigbee2mqtt/configuration.yaml
fi

mkdir -p volumes/qredis/data/

mkdir -p volumes/qpihole/etc-dnsmasq.d/
cat <<EOF > volumes/qpihole/etc-dnsmasq.d/99-custom.conf

EOF

# Determine network details
export NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}')
export SUBNET=$(ip -4 addr show $NETWORK_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | awk -F'/' '{print $1}' | awk -F'.' '{print $1"."$2"."$3"}' )
export GATEWAY=$(ip route | grep default | awk '{print $3}')
export IPRANGE=$(echo $SUBNET".0/24")

echo "Using network interface: $NETWORK_INTERFACE"
echo "Using subnet: $SUBNET"
echo "Using gateway: $GATEWAY"
echo "Using IP range: $IPRANGE"

cat <<EOF > docker-compose.yml
version: "3.3"
services:
  redis:
    image: redis:alpine
    restart: always
    volumes:
      - ./volumes/qredis/data:/data
  clock:
    image: rqure/clock:v2.2.2
    restart: always
  audio-player:
    image: rqure/audio-player:v1.2.3
    restart: always
  prayer:
    image: rqure/adhan:v2.2.3
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
    networks:
      qnet:
        ipv4_address: ${SUBNET}.10
  mqttgateway:
    image: rqure/mqttgateway:v1.2.2
    restart: always
    environment:
      - QMQ_LOG_LEVEL=0
  garage:
    image: rqure/garage:v1.2.2
    restart: always
    networks:
      qnet:
        ipv4_address: ${SUBNET}.11
  webgateway:
    image: rqure/webgateway:v0.0.4
    restart: always
    networks:
      qnet:
        ipv4_address: ${SUBNET}.12
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
      - WG_POST_UP=iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE
      - WG_POST_DOWN=iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth2 -j MASQUERADE
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
    networks:
      qnet:
        ipv4_address: ${SUBNET}.13
  pihole:
    image: pihole/pihole:latest
    environment:
      TZ: 'America/Toronto'
      WEBPASSWORD: 'yourpassword'
    volumes:
      - './etc-pihole/:/etc/pihole/'
      - './etc-dnsmasq.d/:/etc/dnsmasq.d/'
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
    cap_add:
      - NET_ADMIN
    networks:
      qnet:
        ipv4_address: ${SUBNET}.14
networks:
  qnet:
    driver: macvlan
    driver_opts:
      parent: ${NETWORK_INTERFACE}
    ipam:
      config:
        - subnet: ${IPRANGE}
          gateway: ${GATEWAY}
    
EOF

# docker-compose up -d
