#!/bin/bash

# Contract Addresses
# Deployed with superchain contracts
ROOT_GAUGE=
REWARDS_0=
REWARDS_1=

# ENV Variables
source .env
ETHERSCAN_API_KEY=$OPTIMISM_ETHERSCAN_API_KEY
ETHERSCAN_VERIFIER_URL=$OPTIMISM_ETHERSCAN_VERIFIER_URL
RPC_URL=$OPTIMISM_RPC_URL
CHAIN_ID=10

ROOT_GAUGE_FACTORY=$(cast call $ROOT_GAUGE "gaugeFactory()(address)" --rpc-url $RPC_URL)
ROOT_GAUGE_REWARD_TOKEN=$(cast call $ROOT_GAUGE "rewardToken()(address)" --rpc-url $RPC_URL)
ROOT_GAUGE_XERC20=$(cast call $ROOT_GAUGE "xerc20()(address)" --rpc-url $RPC_URL)
ROOT_GAUGE_LOCKBOX=$(cast call $ROOT_GAUGE "lockbox()(address)" --rpc-url $RPC_URL)
ROOT_GAUGE_BRIDGE=$(cast call $ROOT_GAUGE "bridge()(address)" --rpc-url $RPC_URL)
ROOT_GAUGE_VOTER=$(cast call $ROOT_GAUGE "voter()(address)" --rpc-url $RPC_URL)
ROOT_GAUGE_CHAINID=$(cast call $ROOT_GAUGE "chainid()(uint256)" --rpc-url $RPC_URL | awk '{ print $1 }')

ROOT_FEES=$(cast call $ROOT_GAUGE_VOTER "gaugeToFees(address)(address)" $ROOT_GAUGE --rpc-url $RPC_URL)
ROOT_INCENTIVE=$(cast call $ROOT_GAUGE_VOTER "gaugeToBribe(address)(address)" $ROOT_GAUGE --rpc-url $RPC_URL)

ROOT_FEES_BRIDGE=$ROOT_GAUGE_BRIDGE
ROOT_FEES_VOTER=$ROOT_GAUGE_VOTER
ROOT_FEES_INCENTIVE=$(cast call $ROOT_FEES "incentiveVotingReward()(address)" --rpc-url $RPC_URL)

ROOT_INCENTIVE_BRIDGE=$ROOT_GAUGE_BRIDGE
ROOT_INCENTIVE_VOTER=$ROOT_GAUGE_VOTER

# RootGauge
forge verify-contract \
    $ROOT_GAUGE \
    src/root/gauges/RootGauge.sol:RootGauge \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address,address,address,uint256)()" \
    $ROOT_GAUGE_FACTORY \
    $ROOT_GAUGE_REWARD_TOKEN \
    $ROOT_GAUGE_XERC20 \
    $ROOT_GAUGE_LOCKBOX \
    $ROOT_GAUGE_BRIDGE \
    $ROOT_GAUGE_VOTER \
    $ROOT_GAUGE_CHAINID \
    ) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# RootFees
forge verify-contract \
    $ROOT_FEES \
    src/root/rewards/RootFeesVotingReward.sol:RootFeesVotingReward \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address[]memory)()" \
    $ROOT_FEES_BRIDGE \
    $ROOT_FEES_VOTER \
    $ROOT_FEES_INCENTIVE \
    "[$REWARDS_0, $REWARDS_1]" \
    ) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# RootIncentives
forge verify-contract \
    $ROOT_INCENTIVE \
    src/root/rewards/RootIncentiveVotingReward.sol:RootIncentiveVotingReward \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address[]memory)()" \
    $ROOT_INCENTIVE_BRIDGE \
    $ROOT_INCENTIVE_VOTER \
    "[$REWARDS_0, $REWARDS_1]" \
    ) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL
