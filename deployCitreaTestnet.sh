#!/bin/sh

set -e

# Run anvil.sh in another shell before running this

# To load the variables in the .env file
. ./.env

# To deploy and verify our contract
forge script script/CircuitBreakerToken.s.sol:Deploy --rpc-url "https://rpc.testnet.citrea.xyz" --sender $SENDER --private-key $PRIVATE_KEY --broadcast -v
