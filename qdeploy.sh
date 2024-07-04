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
#if [ -z "$(ls -A volumes/qredis/data/)" ]; then
#
#fi

# Deploy the stack
docker stack deploy --compose-file=docker-compose.yml qservice
