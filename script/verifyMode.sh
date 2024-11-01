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
POOL_ADMIN="0xA6074AcC04DeAb343881882c896555A1Ba2E9d46"
PAUSER="0xA6074AcC04DeAb343881882c896555A1Ba2E9d46"
FEE_MANAGER="0xA6074AcC04DeAb343881882c896555A1Ba2E9d46"
TOKEN_ADMIN="0x0000000000000000000000000000000000000001"
BRIDGE_OWNER="0x0000000000000000000000000000000000000001"
MODULE_OWNER="0x0000000000000000000000000000000000000001"
MAILBOX="0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7"
ISM="0x0000000000000000000000000000000000000000"
ADDRESS_ZERO="0x0000000000000000000000000000000000000000"
RECIPIENT="0xb8804281fc224a4E597A3f256b53C9Ed3C89B6c3"
SFS="0x8680CEaBcb9b56913c519c069Add6Bc3494B7020"
# ModeXERC20Factory.tokenId
TOKEN_ID=

# ENV Variables
source .env
ETHERSCAN_API_KEY=$MODE_ETHERSCAN_API_KEY
ETHERSCAN_VERIFIER_URL=$MODE_ETHERSCAN_VERIFIER_URL
CHAIN_ID=34443

# ModePool
forge verify-contract \
    $LEAF_POOL_IMPLEMENTATION \
    src/pools/extensions/ModePool.sol:ModePool \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor()()") \
    --compiler-version "v0.8.27"

# ModePoolFactory
forge verify-contract \
    $LEAF_POOL_FACTORY \
    src/pools/extensions/ModePoolFactory.sol:ModePoolFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address)()" $LEAF_POOL_IMPLEMENTATION $POOL_ADMIN $PAUSER $FEE_MANAGER $RECIPIENT) \
    --compiler-version "v0.8.27"

# ModeLeafGaugeFactory
forge verify-contract \
    $LEAF_GAUGE_FACTORY \
    src/gauges/extensions/ModeLeafGaugeFactory.sol:ModeLeafGaugeFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address)()" $LEAF_VOTER $LEAF_X_VELO $LEAF_MESSAGE_BRIDGE) \
    --compiler-version "v0.8.27"

# VotingRewardsFactory
forge verify-contract \
    $LEAF_VOTING_REWARDS_FACTORY \
    src/rewards/VotingRewardsFactory.sol:VotingRewardsFactory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $LEAF_VOTER $LEAF_MESSAGE_BRIDGE) \
    --compiler-version "v0.8.27"

# ModeLeafVoter
forge verify-contract \
    $LEAF_VOTER \
    src/voter/extensions/ModeLeafVoter.sol:ModeLeafVoter \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address)()" $LEAF_MESSAGE_BRIDGE $RECIPIENT) \
    --compiler-version "v0.8.27"

# ModeXERC20Factory
forge verify-contract \
    $LEAF_X_FACTORY \
    src/xerc20/extensions/ModeXERC20Factory.sol:ModeXERC20Factory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address)()" $TOKEN_ADMIN $ADDRESS_ZERO $RECIPIENT) \
    --compiler-version "v0.8.27" \
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY


# XERC20
forge verify-contract \
    $LEAF_X_VELO \
    src/xerc20/XERC20.sol:XERC20 \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(string,string,address,address)()" "Superchain Velodrome" "XVELO" $TOKEN_ADMIN $ADDRESS_ZERO $SFS $TOKEN_ID) \
    --compiler-version "v0.8.27" \
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY

# ModeTokenBridge
forge verify-contract \
    $LEAF_TOKEN_BRIDGE \
    src/bridge/extensions/ModeTokenBridge.sol:ModeTokenBridge \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address,address)()" $BRIDGE_OWNER $LEAF_X_VELO $MAILBOX $ISM $RECIPIENT) \
    --compiler-version "v0.8.27"

# ModeLeafMessageBridge
forge verify-contract \
    $LEAF_MESSAGE_BRIDGE \
    src/bridge/extensions/ModeLeafMessageBridge.sol:ModeLeafMessageBridge \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address,address)()" $BRIDGE_OWNER $LEAF_X_VELO $LEAF_VOTER $LEAF_MESSAGE_MODULE $RECIPIENT) \
    --compiler-version "v0.8.27"

# ModeLeafHLMessageModule
forge verify-contract \
    $LEAF_MESSAGE_MODULE \
    src/bridge/extensions/hyperlane/ModeLeafHLMessageModule.sol:ModeLeafHLMessageModule \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address)()" $MODULE_OWNER $LEAF_MESSAGE_BRIDGE $MAILBOX $ISM) \
    --compiler-version "v0.8.27"

# ModeRouter
forge verify-contract \
    $LEAF_ROUTER \
    src/extensions/ModeRouter.sol:ModeRouter \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address)()" $LEAF_POOL_FACTORY $WETH $RECIPIENT) \
    --compiler-version "v0.8.27"
