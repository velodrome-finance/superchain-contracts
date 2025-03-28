#!/bin/bash

# Superchain Root Contract Addresses
VOTER="0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C"
ROOT_POOL_FACTORY="0x31832f2a97Fd20664D76Cc421207669b55CE4BC0"
ROOT_MESSAGE_BRIDGE="0xF278761576f45472bdD721EACA19317cE159c011"
RATE_LIMIT_LIBRARY="0x8326B5f31549d12943088CF3F8Dd637dd6465a99"
ADDRESS_ZERO="0x0000000000000000000000000000000000000000"

# Load Env Variables
source .env
RPC_URL=$OPTIMISM_RPC_URL
ETHERSCAN_VERIFIER_URL=$OPTIMISM_ETHERSCAN_VERIFIER_URL
ETHERSCAN_API_KEY=$OPTIMISM_ETHERSCAN_API_KEY
CHAIN_ID=10

# Ensure all Script parameters are set
if [ -z "${RPC_URL}" ] || [ -z "${ETHERSCAN_VERIFIER_URL}" || [ -z "${ETHERSCAN_API_KEY}" ]; then
    echo "Error: One or more required Environment variables are not set."
    echo "Please ensure the following variables are set in the .env file:"
    echo "- OPTIMISM_RPC_URL;"
    echo "- OPTIMISM_ETHERSCAN_API_KEY;"
    echo "- OPTIMISM_ETHERSCAN_VERIFIER_URL."
    exit 1
fi

# Fetch Pool with Gauge for Verification
ALL_POOLS_LENGTH=$(cast call $ROOT_POOL_FACTORY "allPoolsLength()(uint256)" --rpc-url $RPC_URL)

# Iterate through pools in factory to fetch a Root Gauge
for ((i=0; i<ALL_POOLS_LENGTH; i++)); do
    ROOT_POOL=$(cast call $ROOT_POOL_FACTORY "allPools(uint256)(address)" $i --rpc-url $RPC_URL)
    ROOT_GAUGE=$(cast call $VOTER "gauges(address)(address)" $ROOT_POOL --rpc-url $RPC_URL)

    # Leave loop once a Pool with Gauge is found
    if [[ "$ROOT_GAUGE" != "$ADDRESS_ZERO" ]]; then
        break
    fi
done

if [[ "$ROOT_GAUGE" == "$ADDRESS_ZERO" ]]; then
    echo "Error: No Pool with Gauge has been found."
    exit 1
fi

# Verification Parameters
REWARDS_0=$(cast call $ROOT_POOL "token0()(address)" --rpc-url $RPC_URL)
REWARDS_1=$(cast call $ROOT_POOL "token1()(address)" --rpc-url $RPC_URL)

ROOT_FEES=$(cast call $VOTER "gaugeToFees(address)(address)" $ROOT_GAUGE --rpc-url $RPC_URL)
ROOT_INCENTIVE=$(cast call $VOTER "gaugeToBribe(address)(address)" $ROOT_GAUGE --rpc-url $RPC_URL)

LEAF_CHAIN_ID=34443
ROOT_GAUGE_FACTORY=$(cast call $ROOT_GAUGE "gaugeFactory()(address)" --rpc-url $RPC_URL)
ROOT_REWARD_TOKEN=$(cast call $ROOT_GAUGE "rewardToken()(address)" --rpc-url $RPC_URL)
ROOT_XERC20=$(cast call $ROOT_GAUGE "xerc20()(address)" --rpc-url $RPC_URL)
ROOT_LOCKBOX=$(cast call $ROOT_GAUGE "lockbox()(address)" --rpc-url $RPC_URL)

# RootGauge
forge verify-contract \
    $ROOT_GAUGE \
    src/root/gauges/RootGauge.sol:RootGauge \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address,address,address,uint256)()" \
        $ROOT_GAUGE_FACTORY \
        $ROOT_REWARD_TOKEN \
        $ROOT_XERC20 \
        $ROOT_LOCKBOX \
        $ROOT_MESSAGE_BRIDGE \
        $VOTER \
        $LEAF_CHAIN_ID \
    ) \
    --compiler-version "v0.8.27" \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY

# RootFees
forge verify-contract \
    $ROOT_FEES \
    src/root/rewards/RootFeesVotingReward.sol:RootFeesVotingReward \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address,address[]memory)()" \
        $ROOT_MESSAGE_BRIDGE \
        $VOTER \
        $ROOT_INCENTIVE \
        "[$REWARDS_0, $REWARDS_1]" \
    ) \
    --compiler-version "v0.8.27" \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY

# RootIncentives
forge verify-contract \
    $ROOT_INCENTIVE \
    src/root/rewards/RootIncentiveVotingReward.sol:RootIncentiveVotingReward \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address,address[]memory)()" \
        $ROOT_MESSAGE_BRIDGE \
        $VOTER \
        "[$REWARDS_0, $REWARDS_1]" \
    ) \
    --compiler-version "v0.8.27" \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY
