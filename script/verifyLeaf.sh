#!/bin/bash

# Contract Addresses
# Deployed with superchain contracts
LEAF_POOL_IMPLEMENTATION=
LEAF_POOL_FACTORY=
LEAF_GAUGE_FACTORY=
LEAF_VOTING_REWARDS_FACTORY=
LEAF_VOTER=

LEAF_X_FACTORY=
LEAF_X_VELO=

LEAF_TOKEN_BRIDGE=
LEAF_MESSAGE_BRIDGE=
LEAF_MESSAGE_MODULE=

LEAF_ROUTER=

RATE_LIMIT_LIBRARY=

# V2 Constants
WETH="0x4200000000000000000000000000000000000006"
POOL_ADMIN="0x607EbA808EF2685fAc3da68aB96De961fa8F3312"
PAUSER="0x607EbA808EF2685fAc3da68aB96De961fa8F3312"
FEE_MANAGER="0x607EbA808EF2685fAc3da68aB96De961fa8F3312"
TOKEN_ADMIN="0x0000000000000000000000000000000000000001"
BRIDGE_OWNER="0x0000000000000000000000000000000000000001"
MODULE_OWNER="0x0000000000000000000000000000000000000001"
MAILBOX="0x8358D8291e3bEDb04804975eEa0fe9fe0fAfB147"
ISM="0x0000000000000000000000000000000000000000"
ADDRESS_ZERO="0x0000000000000000000000000000000000000000"

# ENV Variables
source .env
ETHERSCAN_API_KEY=
ETHERSCAN_VERIFIER_URL=$BOB_ETHERSCAN_VERIFIER_URL
CHAIN_ID=60808

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
    --verifier-url $ETHERSCAN_VERIFIER_URL

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
    --verifier-url $ETHERSCAN_VERIFIER_URL

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
    --verifier-url $ETHERSCAN_VERIFIER_URL

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
    --verifier-url $ETHERSCAN_VERIFIER_URL

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
    --verifier-url $ETHERSCAN_VERIFIER_URL

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
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY

# TokenBridge
forge verify-contract \
    $LEAF_TOKEN_BRIDGE \
    src/bridge/TokenBridge.sol:TokenBridge \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address)()" $BRIDGE_OWNER $LEAF_X_VELO $MAILBOX $ISM) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL

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
    --verifier-url $ETHERSCAN_VERIFIER_URL

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
    --verifier-url $ETHERSCAN_VERIFIER_URL

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
    --verifier-url $ETHERSCAN_VERIFIER_URL
