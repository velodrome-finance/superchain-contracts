#!/bin/bash

# Superchain Contract Addresses
# Deployed via create3. Addresses are the same across all leaf chains
LEAF_POOL_IMPLEMENTATION="0x10499d88Bd32AF443Fc936F67DE32bE1c8Bb374C"
LEAF_POOL_FACTORY="0x31832f2a97Fd20664D76Cc421207669b55CE4BC0"
LEAF_GAUGE_FACTORY="0x42e403b73898320f23109708b0ba1Ae85838C445"
LEAF_VOTING_REWARDS_FACTORY="0x7dc9fd82f91B36F416A89f5478375e4a79f4Fb2F"
LEAF_VOTER="0x97cDBCe21B6fd0585d29E539B1B99dAd328a1123"

LEAF_X_FACTORY="0x73CaE4450f11f4A33a49C880CE3E8E56a9294B31"
LEAF_X_VELO="0x7f9AdFbd38b669F03d1d11000Bc76b9AaEA28A81"

LEAF_TOKEN_BRIDGE="0xA7287a56C01ac8Baaf8e7B662bDB41b10889C7A6"
LEAF_MESSAGE_BRIDGE="0xF278761576f45472bdD721EACA19317cE159c011"
LEAF_MESSAGE_MODULE="0xF385603a12Be8b7B885222329c581FDD1C30071D"

LEAF_ROUTER="0x3a63171DD9BebF4D07BC782FECC7eb0b890C2A45"

# Script Parameters
CHAIN_NAME=
RATE_LIMIT_LIBRARY=

# Load Env Variables
source .env
RPC_URL=$(eval echo \$${CHAIN_NAME}_RPC_URL)
ETHERSCAN_VERIFIER_URL=$(eval echo \$${CHAIN_NAME}_ETHERSCAN_VERIFIER_URL)
ETHERSCAN_API_KEY=$(eval echo \$${CHAIN_NAME}_ETHERSCAN_API_KEY)

# Ensure all Script parameters are set
if [ -z "${CHAIN_NAME}" ]; then
    echo "Error: Chain name not specified."
    echo "Please ensure the CHAIN_NAME variable is set in the script."
    exit 1
fi

if [ -z "${RPC_URL}" ] || [ -z "${ETHERSCAN_VERIFIER_URL}" ]; then
    echo "Error: One or more required Environment variables are not set."
    echo "Please ensure the following variables are set in the .env file:"
    echo "- ${CHAIN_NAME}_RPC_URL;"
    echo "- ${CHAIN_NAME}_ETHERSCAN_VERIFIER_URL."
    exit 1
fi

if [ -z "${RATE_LIMIT_LIBRARY}" ]; then
    echo "WARNING: Rate Limit library address is not set. XERC20 related contracts will not be verified."
fi

# Deployment Parameters
CHAIN_ID=$(cast chain-id --rpc-url $RPC_URL)
WETH=$(cast call $LEAF_ROUTER "weth()(address)" --rpc-url $RPC_URL)
POOL_ADMIN=$(cast call $LEAF_POOL_FACTORY "poolAdmin()(address)" --rpc-url $RPC_URL)
PAUSER=$(cast call $LEAF_POOL_FACTORY "pauser()(address)" --rpc-url $RPC_URL)
FEE_MANAGER=$(cast call $LEAF_POOL_FACTORY "feeManager()(address)" --rpc-url $RPC_URL)
CUSTOM_FEE_MODULE=$(cast call $LEAF_POOL_FACTORY "feeModule()(address)" --rpc-url $RPC_URL)
TOKEN_ADMIN=$(cast call $LEAF_X_FACTORY "owner()(address)" --rpc-url $RPC_URL)
BRIDGE_OWNER=$(cast call $LEAF_MESSAGE_BRIDGE "owner()(address)" --rpc-url $RPC_URL)
MODULE_OWNER=$(cast call $LEAF_MESSAGE_MODULE "owner()(address)" --rpc-url $RPC_URL)
MAILBOX=$(cast call $LEAF_MESSAGE_MODULE "mailbox()(address)" --rpc-url $RPC_URL)
ISM=$(cast call $LEAF_MESSAGE_MODULE "interchainSecurityModule()(address)" --rpc-url $RPC_URL)
ADDRESS_ZERO="0x0000000000000000000000000000000000000000"

# Pool
forge verify-contract \
    $LEAF_POOL_IMPLEMENTATION \
    src/pools/Pool.sol:Pool \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor()()") \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# PoolFactory
forge verify-contract \
    $LEAF_POOL_FACTORY \
    src/pools/PoolFactory.sol:PoolFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address)()" $LEAF_POOL_IMPLEMENTATION $POOL_ADMIN $PAUSER $FEE_MANAGER) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# CustomFeeModule
forge verify-contract \
    $CUSTOM_FEE_MODULE \
    src/fees/CustomFeeModule.sol:CustomFeeModule \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address)()" $LEAF_POOL_FACTORY) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# LeafGaugeFactory
forge verify-contract \
    $LEAF_GAUGE_FACTORY \
    src/gauges/LeafGaugeFactory.sol:LeafGaugeFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $LEAF_VOTER $LEAF_MESSAGE_BRIDGE) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# VotingRewardsFactory
forge verify-contract \
    $LEAF_VOTING_REWARDS_FACTORY \
    src/rewards/VotingRewardsFactory.sol:VotingRewardsFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $LEAF_VOTER $LEAF_MESSAGE_BRIDGE) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# LeafVoter
forge verify-contract \
    $LEAF_VOTER \
    src/voter/LeafVoter.sol:LeafVoter \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address)()" $LEAF_MESSAGE_BRIDGE) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# RateLimit Library
forge verify-contract \
    $RATE_LIMIT_LIBRARY \
    src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# XERC20Factory
forge verify-contract \
    $LEAF_X_FACTORY \
    src/xerc20/XERC20Factory.sol:XERC20Factory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $TOKEN_ADMIN $ADDRESS_ZERO) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY} \
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY

# XERC20
forge verify-contract \
    $LEAF_X_VELO \
    src/xerc20/XERC20.sol:XERC20 \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(string,string,address,address)()" "Superchain Velodrome" "XVELO" $TOKEN_ADMIN $ADDRESS_ZERO) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY} \
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY

# LeafTokenBridge
forge verify-contract \
    $LEAF_TOKEN_BRIDGE \
    src/bridge/LeafTokenBridge.sol:LeafTokenBridge \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address)()" $BRIDGE_OWNER $LEAF_X_VELO $MAILBOX $ISM) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# LeafMessageBridge
forge verify-contract \
    $LEAF_MESSAGE_BRIDGE \
    src/bridge/LeafMessageBridge.sol:LeafMessageBridge \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address)()" $BRIDGE_OWNER $LEAF_X_VELO $LEAF_VOTER $LEAF_MESSAGE_MODULE) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# LeafHLMessageModule
forge verify-contract \
    $LEAF_MESSAGE_MODULE \
    src/bridge/hyperlane/LeafHLMessageModule.sol:LeafHLMessageModule \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address)()" $MODULE_OWNER $LEAF_MESSAGE_BRIDGE $MAILBOX $ISM) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# Router
forge verify-contract \
    $LEAF_ROUTER \
    src/Router.sol:Router \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $LEAF_POOL_FACTORY $WETH) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}
