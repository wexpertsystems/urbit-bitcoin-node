#!/bin/bash
##########################
# Set host.docker.internal
sudo /usr/bin/append-to-hosts "$(ip -4 route list match 0/0 | awk '{print $3 "\thost.docker.internal"}')"
echo Running modified mainnet script...
export BTC_RPC_PORT=${BITCOIN_RPC_PORT}
export ELECTRS_HOST=${ELECTRUM_IP}
export ELECTRS_PORT=${ELECTRUM_PORT}
# docker-compose.yml also passes the folllowing env vars:
# $BITCOIN_RPC_USER, $BITCOIN_RPC_PASS, $BITCOIN_RPC_AUTH,
# and $BITCOIN_IP
export PROXY_PORT=50002

node src/server.js &

