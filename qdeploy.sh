# Set environment
export HOST_ADDR=$(curl -s https://api.ipify.org)
export VPN_ANONYMOUS_CLIENT_NAME="qanonymous"

# Create volumes for config and data
mkdir -p volumes/openvpn/
if [ ! "$(ls -A volumes/openvpn/)" ]; then
    docker run -v ./volumes/openvpn:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u udp://vpn.qmq
    docker run -v ./volumes/openvpn:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki
    docker run -v ./volumes/openvpn:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full $VPN_ANONYMOUS_CLIENT_NAME nopass
fi

mkdir -p volumes/qexchange/
if [ ! -f volumes/qexchange/exchanges.json ]; then
    curl https://raw.githubusercontent.com/rqure/qexchange/main/exchanges.json -o volumes/qexchange/exchanges.json
fi

mkdir -p volumes/qzigbee2mqtt/
if [ ! -f volumes/qzigbee2mqtt/configuration.yaml ]; then
    curl https://raw.githubusercontent.com/rqure/qzigbee2mqtt/main/configuration.yaml -o volumes/qzigbee2mqtt/configuration.yaml
fi

mkdir -p volumes/certs/
if [ ! "$(ls -A volumes/certs/)" ]; then
    docker run -v ./volumes/openvpn:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient $VPN_ANONYMOUS_CLIENT_NAME > $VPN_ANONYMOUS_CLIENT_NAME.ovpn
fi

# Deploy the stack
docker stack deploy --compose-file=docker-compose.yml qservice
