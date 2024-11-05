#!/bin/bash

# Contract Addresses
# Deployed with superchain contracts
LEAF_GAUGE=
REWARDS_0=
REWARDS_1=

# ENV Variables
source .env
ETHERSCAN_API_KEY=
ETHERSCAN_VERIFIER_URL=$MODE_ETHERSCAN_VERIFIER_URL
RPC_URL=$MODE_RPC_URL
CHAIN_ID=34443

LEAF_GAUGE_STAKING_TOKEN=$(cast call $LEAF_GAUGE "stakingToken()(address)" --rpc-url $RPC_URL)
LEAF_GAUGE_FEES_VOTING_REWARD=$(cast call $LEAF_GAUGE "feesVotingReward()(address)" --rpc-url $RPC_URL)
LEAF_GAUGE_REWARD_TOKEN=$(cast call $LEAF_GAUGE "rewardToken()(address)" --rpc-url $RPC_URL)
LEAF_GAUGE_VOTER=$(cast call $LEAF_GAUGE "voter()(address)" --rpc-url $RPC_URL)
LEAF_GAUGE_BRIDGE=$(cast call $LEAF_GAUGE "bridge()(address)" --rpc-url $RPC_URL)
LEAF_GAUGE_IS_POOL=$(cast call $LEAF_GAUGE "isPool()(bool)" --rpc-url $RPC_URL)

LEAF_FEES=$(cast call $LEAF_GAUGE_VOTER "gaugeToFees(address)(address)" $LEAF_GAUGE --rpc-url $RPC_URL)
LEAF_INCENTIVE=$(cast call $LEAF_GAUGE_VOTER "gaugeToIncentive(address)(address)" $LEAF_GAUGE --rpc-url $RPC_URL)

LEAF_FEES_BRIDGE=$LEAF_GAUGE_BRIDGE
LEAF_FEES_VOTER=$LEAF_GAUGE_VOTER
LEAF_FEES_INCENTIVE=$LEAF_INCENTIVE

LEAF_INCENTIVE_BRIDGE=$LEAF_GAUGE_BRIDGE
LEAF_INCENTIVE_VOTER=$LEAF_GAUGE_VOTER

# LeafGauge
forge verify-contract \
    $LEAF_GAUGE \
    src/gauges/LeafGauge.sol:LeafGauge \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address,address,bool)()" \
    $LEAF_GAUGE_STAKING_TOKEN \
    $LEAF_GAUGE_FEES_VOTING_REWARD \
    $LEAF_GAUGE_REWARD_TOKEN \
    $LEAF_GAUGE_VOTER \
    $LEAF_GAUGE_BRIDGE \
    $LEAF_GAUGE_IS_POOL \
    ) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# LeafFees
forge verify-contract \
    $LEAF_FEES \
    src/rewards/FeesVotingReward.sol:FeesVotingReward \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address[]memory)()" \
    $LEAF_FEES_VOTER \
    $LEAF_FEES_BRIDGE \
    $LEAF_FEES_INCENTIVE \
    "[$REWARDS_0, $REWARDS_1]" \
    ) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL

# LeafIncentives
forge verify-contract \
    $LEAF_INCENTIVE \
    src/rewards/IncentiveVotingReward.sol:IncentiveVotingReward \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address[]memory)()" \
    $LEAF_INCENTIVE_VOTER \
    $LEAF_INCENTIVE_BRIDGE \
    "[$REWARDS_0, $REWARDS_1]" \
    ) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL
