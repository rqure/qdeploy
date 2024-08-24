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
    ip_with_mask=$(ip -4 addr show dev $NETWORK_INTERFACE | grep inet | awk '{print $2}')
    offset=0  # Offset to add to the base IP
    
    # Extract IP address and mask
    ip=${ip_with_mask%/*}
    mask=${ip_with_mask#*/}
    
    # Function to convert an IP address to an integer
    ip_to_int() {
      local ip=$1
      local a b c d
      IFS=. read -r a b c d <<< "$ip"
      echo "$(( (a << 24) + (b << 16) + (c << 8) + d ))"
    }
    
    # Function to convert an integer back to an IP address
    int_to_ip() {
      local int=$1
      echo "$(( (int >> 24) & 255 )).$(( (int >> 16) & 255 )).$(( (int >> 8) & 255 )).$(( int & 255 ))"
    }
    
    # Convert IP to integer
    ip_int=$(ip_to_int "$ip")
    
    # Calculate the subnet mask in integer form
    mask_int=$(( (0xFFFFFFFF << (32 - mask)) & 0xFFFFFFFF ))
    
    # Calculate the network base address by applying the subnet mask
    network_int=$((ip_int & mask_int))
    
    # Add the offset to the base network address
    new_ip_int=$((network_int + offset))
    
    # Ensure the new IP is within the same subnet
    if (( (new_ip_int & mask_int) != network_int )); then
      echo "Error: Offset results in an IP address outside the subnet."
      exit 1
    fi
    
    # Convert the new integer back to an IP address
    new_ip=$(int_to_ip "$new_ip_int")
    
    # Output the new IP address with the original mask
    echo "$new_ip/$mask" > ~/.qnet.subnet.v4
fi

if [ ! -f ~/.qnet.subnet.v6 ]; then
    IP6_WITH_MASK=$(ip -6 addr show dev $NETWORK_INTERFACE scope link | sed -e 's/^.*inet6 \([^ ]*\/[0-9]*\).*$/\1/;t;d')
    # Extract IP address
    IP6_TMP="${IP6_WITH_MASK%/*}"
    # Extract mask
    MASK_TMP="${IP6_WITH_MASK#*/}"
    
    # Split the IP address into segments
    IFS=':' read -ra segments <<< "$IP6_TMP"
    
    # Calculate the number of segments needed for the given prefix length
    segments_required=$((MASK_TMP / 16))
    
    # Reconstruct the subnet
    SUBNET_TMP=""
    for i in $(seq 0 $((segments_required - 1))); do
        SUBNET_TMP+="${segments[$i]}:"
    done
    
    # Fill remaining segments with zeros if necessary
    for i in $(seq $segments_required 7); do
        SUBNET_TMP+="0000:"
    done
    SUBNET_TMP="${SUBNET_TMP%:*}"

    # Function to convert a single hextet to binary
    hextet_to_bin() {
        local hextet=$1
        local bin=""
        for ((i = 0; i < ${#hextet}; i++)); do
            local hex_digit=${hextet:i:1}
            case $hex_digit in
                0) bin="${bin}0000" ;;
                1) bin="${bin}0001" ;;
                2) bin="${bin}0010" ;;
                3) bin="${bin}0011" ;;
                4) bin="${bin}0100" ;;
                5) bin="${bin}0101" ;;
                6) bin="${bin}0110" ;;
                7) bin="${bin}0111" ;;
                8) bin="${bin}1000" ;;
                9) bin="${bin}1001" ;;
                a|A) bin="${bin}1010" ;;
                b|B) bin="${bin}1011" ;;
                c|C) bin="${bin}1100" ;;
                d|D) bin="${bin}1101" ;;
                e|E) bin="${bin}1110" ;;
                f|F) bin="${bin}1111" ;;
            esac
        done
        echo "$bin"
    }
    
    # Function to convert binary to hexadecimal hextet
    bin_to_hextet() {
        local bin=$1
        local hex=""
        for ((i = 0; i < 16; i+=4)); do
            local nibble=${bin:i:4}
            local hex_digit=$(printf "%x" "$((2#$nibble))")
            hex="${hex}${hex_digit}"
        done
        echo "${hex}"
    }
    
    # Function to convert an IPv6 address to binary representation
    ipv6_to_bin() {
        local ipv6=$1
        local bin=""
        # Convert each hextet to binary
        for hextet in $(echo "$ipv6" | sed 's/::/:/g' | tr ':' ' '); do
            printf -v bin "${bin}$(hextet_to_bin "$hextet")"
        done
        echo "$bin"
    }
    
    # Function to find the common prefix length
    common_prefix_length() {
        local bin1=$1
        local bin2=$2
        local len=${#bin1}
        local common_len=0
        for ((i = 0; i < len; i++)); do
            if [[ ${bin1:i:1} == ${bin2:i:1} ]]; then
                common_len=$((common_len + 1))
            else
                break
            fi
        done
        echo "$common_len"
    }
    
    # Function to compute the subnet prefix
    compute_subnet() {
        local addr_bin=$1
        local prefix_len=$2
        local mask_bin=""
        local subnet_bin=""
    
        # Create the subnet mask in binary
        for ((i = 0; i < 128; i++)); do
            if ((i < prefix_len)); then
                mask_bin="${mask_bin}1"
            else
                mask_bin="${mask_bin}0"
            fi
        done
    
        # Apply the mask to the address
        for ((i = 0; i < 128; i++)); do
            if [[ ${mask_bin:i:1} == "1" ]]; then
                subnet_bin="${subnet_bin}${addr_bin:i:1}"
            else
                subnet_bin="${subnet_bin}0"
            fi
        done
    
        # Convert binary subnet to hexadecimal hextets
        local subnet_prefix=""
        for ((i = 0; i < 128; i+=16)); do
            local hextet_bin=${subnet_bin:i:16}
            local hextet_hex=$(bin_to_hextet "$hextet_bin")
            subnet_prefix="${subnet_prefix}${hextet_hex}:"
        done
    
        # Remove the trailing colon
        echo "${subnet_prefix%:}"
    }
    
    addr1=$SUBNET_TMP
    addr2=$(ip -6 route | grep default | awk '{print $3}')
    
    # Convert IPv6 addresses to binary
    bin1=$(ipv6_to_bin "$addr1")
    bin2=$(ipv6_to_bin "$addr2")
    
    # Find the common prefix length
    prefix_length=$(common_prefix_length "$bin1" "$bin2")
    
    # Compute the subnet
    subnet=$(compute_subnet "$bin1" "$prefix_length")
    
    # Display the subnet with the prefix
    echo "$subnet/$prefix_length" > ~/.qnet.subnet.v6
fi

if [ ! -f ~/.qnet.pihole.v4 ]; then
    ip_with_mask=$(ip -4 addr show dev $NETWORK_INTERFACE | grep inet | awk '{print $2}')
    offset=10  # Offset to add to the base IP
    
    # Extract IP address and mask
    ip=${ip_with_mask%/*}
    mask=${ip_with_mask#*/}
    
    # Function to convert an IP address to an integer
    ip_to_int() {
      local ip=$1
      local a b c d
      IFS=. read -r a b c d <<< "$ip"
      echo "$(( (a << 24) + (b << 16) + (c << 8) + d ))"
    }
    
    # Function to convert an integer back to an IP address
    int_to_ip() {
      local int=$1
      echo "$(( (int >> 24) & 255 )).$(( (int >> 16) & 255 )).$(( (int >> 8) & 255 )).$(( int & 255 ))"
    }
    
    # Convert IP to integer
    ip_int=$(ip_to_int "$ip")
    
    # Calculate the subnet mask in integer form
    mask_int=$(( (0xFFFFFFFF << (32 - mask)) & 0xFFFFFFFF ))
    
    # Calculate the network base address by applying the subnet mask
    network_int=$((ip_int & mask_int))
    
    # Add the offset to the base network address
    new_ip_int=$((network_int + offset))
    
    # Ensure the new IP is within the same subnet
    if (( (new_ip_int & mask_int) != network_int )); then
      echo "Error: Offset results in an IP address outside the subnet."
      exit 1
    fi
    
    # Convert the new integer back to an IP address
    new_ip=$(int_to_ip "$new_ip_int")
    
    # Output the new IP address with the original mask
    echo "$new_ip" > ~/.qnet.pihole.v4
fi

if [ ! -f ~/.qnet.pihole.v6 ]; then
    IP6_WITH_MASK=$(ip -6 addr show dev $NETWORK_INTERFACE scope link | sed -e 's/^.*inet6 \([^ ]*\/[0-9]*\).*$/\1/;t;d')
    # Extract IP address
    IP6_TMP="${IP6_WITH_MASK%/*}"
    # Extract mask
    MASK_TMP="${IP6_WITH_MASK#*/}"
    
    # Split the IP address into segments
    IFS=':' read -ra segments <<< "$IP6_TMP"
    
    # Calculate the number of segments needed for the given prefix length
    segments_required=$((MASK_TMP / 16))
    
    # Reconstruct the subnet
    SUBNET_TMP=""
    for i in $(seq 0 $((segments_required - 1))); do
        SUBNET_TMP+="${segments[$i]}:"
    done
    
    # Fill remaining segments with zeros if necessary
    for i in $(seq $segments_required 6); do
        SUBNET_TMP+="0000:"
    done
    
    # Remove the trailing colon and append the desired suffix and mask
    IP6_TMP="${SUBNET_TMP%:}:10/${MASK_TMP}"
    echo "$IP6_TMP" > ~/.qnet.pihole.v6
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
    image: rqure/clock:v2.2.2
    restart: always
  audio-player:
    image: rqure/audio-player:v1.2.4
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
  mqttgateway:
    image: rqure/mqttgateway:v1.2.2
    restart: always
    environment:
      - QMQ_LOG_LEVEL=0
  garage:
    image: rqure/garage:v1.2.3
    restart: always
  webgateway:
    image: rqure/webgateway:v0.0.5
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
  pihole:
    image: pihole/pihole:latest
    restart: always
    environment:
      TZ: 'America/Edmonton'
      WEBPASSWORD: 'rqure'
    ports:
      - "${PIHOLEv4}:53:53/tcp"
      - "${PIHOLEv4}:53:53/udp"
      - "[${PIHOLEv6%/*}]:53:53/tcp"
      - "[${PIHOLEv6%/*}]:53:53/udp"
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
