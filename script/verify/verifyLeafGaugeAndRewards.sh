#!/bin/bash

# Superchain Contract Addresses
# Deployed via create3. Addresses are the same across all leaf chains
LEAF_VOTER="0x97cDBCe21B6fd0585d29E539B1B99dAd328a1123"
LEAF_POOL_FACTORY="0x31832f2a97Fd20664D76Cc421207669b55CE4BC0"
LEAF_MESSAGE_BRIDGE="0xF278761576f45472bdD721EACA19317cE159c011"
ADDRESS_ZERO="0x0000000000000000000000000000000000000000"

# Script Parameters
CHAIN_NAME=

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

# Fetch Pool with Gauge for Verification
CHAIN_ID=$(cast chain-id --rpc-url $RPC_URL)
ALL_POOLS_LENGTH=$(cast call $LEAF_POOL_FACTORY "allPoolsLength()(uint256)" --rpc-url $RPC_URL)

# Iterate through pools in factory to fetch a Leaf Gauge
for ((i=0; i<ALL_POOLS_LENGTH; i++)); do
    LEAF_POOL=$(cast call $LEAF_POOL_FACTORY "allPools(uint256)(address)" $i --rpc-url $RPC_URL)
    LEAF_GAUGE=$(cast call $LEAF_VOTER "gauges(address)(address)" $LEAF_POOL --rpc-url $RPC_URL)

    # Leave loop once a Pool with Gauge is found
    if [[ "$LEAF_GAUGE" != "$ADDRESS_ZERO" ]]; then
        break
    fi
done

if [[ "$LEAF_GAUGE" == "$ADDRESS_ZERO" ]]; then
    echo "Error: No Pool with Gauge has been found."
    exit 1
fi

# Verification Parameters
REWARDS_0=$(cast call $LEAF_POOL "token0()(address)" --rpc-url $RPC_URL)
REWARDS_1=$(cast call $LEAF_POOL "token1()(address)" --rpc-url $RPC_URL)

LEAF_FEES=$(cast call $LEAF_VOTER "gaugeToFees(address)(address)" $LEAF_GAUGE --rpc-url $RPC_URL)
LEAF_INCENTIVE=$(cast call $LEAF_VOTER "gaugeToIncentive(address)(address)" $LEAF_GAUGE --rpc-url $RPC_URL)

LEAF_GAUGE_STAKING_TOKEN=$(cast call $LEAF_GAUGE "stakingToken()(address)" --rpc-url $RPC_URL)
LEAF_FEES=$(cast call $LEAF_GAUGE "feesVotingReward()(address)" --rpc-url $RPC_URL)
LEAF_GAUGE_REWARD_TOKEN=$(cast call $LEAF_GAUGE "rewardToken()(address)" --rpc-url $RPC_URL)
LEAF_GAUGE_IS_POOL=$(cast call $LEAF_GAUGE "isPool()(bool)" --rpc-url $RPC_URL)

# LeafGauge
forge verify-contract \
    $LEAF_GAUGE \
    src/gauges/LeafGauge.sol:LeafGauge \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address,address,bool)()" \
    $LEAF_GAUGE_STAKING_TOKEN \
    $LEAF_FEES \
    $LEAF_GAUGE_REWARD_TOKEN \
    $LEAF_VOTER \
    $LEAF_MESSAGE_BRIDGE \
    $LEAF_GAUGE_IS_POOL \
    ) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# LeafFees
forge verify-contract \
    $LEAF_FEES \
    src/rewards/FeesVotingReward.sol:FeesVotingReward \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address[]memory)()" \
    $LEAF_VOTER \
    $LEAF_MESSAGE_BRIDGE \
    "[$REWARDS_0, $REWARDS_1]" \
    ) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}

# LeafIncentives
forge verify-contract \
    $LEAF_INCENTIVE \
    src/rewards/IncentiveVotingReward.sol:IncentiveVotingReward \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address[]memory)()" \
    $LEAF_VOTER \
    $LEAF_MESSAGE_BRIDGE \
    "[$REWARDS_0, $REWARDS_1]" \
    ) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    ${ETHERSCAN_API_KEY:+--etherscan-api-key $ETHERSCAN_API_KEY}
