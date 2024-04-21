# Create .env file
export HOST_ADDR=$(curl -s https://api.ipify.org)

# Create volumes for config and data
mkdir -p volumes/openvpn/

mkdir -p volumes/qexchange/
if [ ! -f volumes/qexchange/exchanges.json ]; then
    curl https://raw.githubusercontent.com/rqure/qexchange/main/exchanges.json -o volumes/qexchange/exchanges.json
fi

mkdir -p volumes/qzigbee2mqtt/
if [ ! -f volumes/qzigbee2mqtt/configuration.yaml ]; then
    curl https://raw.githubusercontent.com/rqure/qzigbee2mqtt/main/configuration.yaml -o volumes/qzigbee2mqtt/configuration.yaml
fi

# Deploy the stack
docker stack deploy --compose-file=docker-compose.yml qservice
