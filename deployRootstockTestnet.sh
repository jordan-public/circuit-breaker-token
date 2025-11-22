#!/bin/zsh

# Run anvil.sh in another shell before running this

# To load the variables in the .env file
source .env

forge script script/CircuitBreakerToken.s.sol:Deploy --legacy --rpc-url "https://rpc.testnet.rootstock.io/lZZVyJCscc9luAu3ByNcsjI9UOAb9H-T" --sender $SENDER --private-key $PRIVATE_KEY --broadcast -vvvv
