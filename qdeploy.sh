# Set environment)
if [ -f ~/.duckdns.subdomains ]; then
    touch ~/.duckdns.subdomains
fi

if [ -f ~/.duckdns.token ]; then
    touch ~/.duckdns.token
fi

if [ -f ~/.wireguard.serverurl ]; then
    touch ~/.wireguard.serverurl
fi

export SUBDOMAINS=$(cat ~/.duckdns.subdomains)
export TOKEN=$(cat ~/.duckdns.token)
export SERVERURL=$(cat ~/.wireguard.serverurl)

# Create volumes for config and data
mkdir -p volumes/duckdns/

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
