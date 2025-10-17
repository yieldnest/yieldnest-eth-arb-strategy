#!/bin/bash

# Usage: ./verify-bytecode.sh [deployment_file] <etherscan_api_key> <rpc_url>

DEPLOYMENT_FILE=${1:-"deployments/mainnet.json"}
ETHERSCAN_API_KEY=$2
RPC_URL=$3

# Parse addresses from deployment JSON
# Extract strategy name from deployment file name (remove chain id suffix)
STRATEGY_NAME=$(basename "$DEPLOYMENT_FILE" .json | sed 's/-[^-]*$//')

ACCOUNTING_MODULE_ADDRESS=$(jq -r ".\"${STRATEGY_NAME}-accountingModule-implementation\"" "$DEPLOYMENT_FILE")
ACCOUNTING_TOKEN_ADDRESS=$(jq -r ".\"${STRATEGY_NAME}-accountingToken-implementation\"" "$DEPLOYMENT_FILE")
FLEX_STRATEGY_ADDRESS=$(jq -r ".\"${STRATEGY_NAME}-implementation\"" "$DEPLOYMENT_FILE")
REWARDS_SWEEPER_ADDRESS=$(jq -r ".\"${STRATEGY_NAME}-rewardsSweeper-implementation\"" "$DEPLOYMENT_FILE")

# Verify contracts
forge verify-bytecode --etherscan-api-key "$ETHERSCAN_API_KEY" "$ACCOUNTING_MODULE_ADDRESS" AccountingModule:AccountingModule --rpc-url "$RPC_URL"

forge verify-bytecode --encoded-constructor-args $(cast abi-encode "constructor(address)" 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) --etherscan-api-key "$ETHERSCAN_API_KEY" "$ACCOUNTING_TOKEN_ADDRESS" AccountingToken:AccountingToken --rpc-url "$RPC_URL"

forge verify-bytecode --etherscan-api-key "$ETHERSCAN_API_KEY" "$FLEX_STRATEGY_ADDRESS" FlexStrategy:FlexStrategy --rpc-url "$RPC_URL"

