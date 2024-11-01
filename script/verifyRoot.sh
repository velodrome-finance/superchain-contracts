#!/bin/bash

# Contract Addresses
# Deployed with superchain contracts
ROOT_POOL_IMPLEMENTATION=
ROOT_POOL_FACTORY=
ROOT_GAUGE_FACTORY=
ROOT_VOTING_REWARDS_FACTORY=

ROOT_X_FACTORY=
ROOT_X_VELO=
ROOT_X_LOCKBOX=

ROOT_TOKEN_BRIDGE=
ROOT_MESSAGE_BRIDGE=
ROOT_MESSAGE_MODULE=

RATE_LIMIT_LIBRARY=

# V2 Constants
WETH="0x4200000000000000000000000000000000000006"
VOTER="0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C"
VELO="0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db"
TOKEN_ADMIN="0x0000000000000000000000000000000000000001"
BRIDGE_OWNER="0x0000000000000000000000000000000000000001"
NOTIFY_ADMIN="0x0000000000000000000000000000000000000001"
EMISSION_ADMIN="0x0000000000000000000000000000000000000001"
DEFAULT_CAP=100
MAILBOX="0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D"
ISM="0x0000000000000000000000000000000000000000"

# ENV Variables
source .env
ETHERSCAN_API_KEY=$OPTIMISM_ETHERSCAN_API_KEY
ETHERSCAN_VERIFIER_URL=$OPTIMISM_ETHERSCAN_VERIFIER_URL
CHAIN_ID=10

# RootPool
forge verify-contract \
    $ROOT_POOL_IMPLEMENTATION \
    src/root/pools/RootPool.sol:RootPool \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor()()") \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# RootPoolFactory
forge verify-contract \
    $ROOT_POOL_FACTORY \
    src/root/pools/RootPoolFactory.sol:RootPoolFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $ROOT_POOL_IMPLEMENTATION $ROOT_MESSAGE_BRIDGE) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# RootGaugeFactory
forge verify-contract \
    $ROOT_GAUGE_FACTORY \
    src/root/gauges/RootGaugeFactory.sol:RootGaugeFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address,address,address,address,address,uint256)()" $VOTER $ROOT_X_VELO $ROOT_X_LOCKBOX $ROOT_MESSAGE_BRIDGE $ROOT_POOL_FACTORY $ROOT_VOTING_REWARDS_FACTORY $NOTIFY_ADMIN $EMISSION_ADMIN $DEFAULT_CAP) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# RootVotingRewardsFactory 
forge verify-contract \
    $ROOT_VOTING_REWARDS_FACTORY \
    src/root/rewards/RootVotingRewardsFactory.sol:RootVotingRewardsFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address)()" $ROOT_MESSAGE_BRIDGE ) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# XERC20Factory
forge verify-contract \
    $ROOT_X_FACTORY \
    src/xerc20/XERC20Factory.sol:XERC20Factory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $TOKEN_ADMIN $VELO) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY

# XERC20
forge verify-contract \
    $ROOT_X_VELO \
    src/xerc20/XERC20.sol:XERC20 \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(string,string,address,address)()" "Superchain Velodrome" "XVELO" $TOKEN_ADMIN $ROOT_X_LOCKBOX) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY

# XERC20LockBox
forge verify-contract \
    $ROOT_X_LOCKBOX \
    src/xerc20/XERC20Lockbox.sol:XERC20Lockbox \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $ROOT_X_VELO $VELO) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# TokenBridge
forge verify-contract \
    $ROOT_TOKEN_BRIDGE \
    src/bridge/TokenBridge.sol:TokenBridge \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address)()" $BRIDGE_OWNER $ROOT_X_VELO $MAILBOX $ISM) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL


# RootMessageBridge
forge verify-contract \
    $ROOT_MESSAGE_BRIDGE \
    src/root/bridge/RootMessageBridge.sol:RootMessageBridge \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address)()" $BRIDGE_OWNER $ROOT_X_VELO $VOTER $WETH) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# RootHLMessageModule
forge verify-contract \
    $ROOT_MESSAGE_MODULE \
    src/root/bridge/hyperlane/RootHLMessageModule.sol:RootHLMessageModule \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $ROOT_MESSAGE_BRIDGE $MAILBOX) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL
