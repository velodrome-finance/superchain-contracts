#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Check if required arguments are provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <chain-name> [verifier-type] [additional_args]"
    echo "Example (simulation only): $0 soneium"
    echo "Example (with deployment): $0 soneium blockscout"
    echo "Example with additional args: $0 soneium blockscout \"--with-gas-price 1000000000\""
    exit 1
fi

CHAIN_NAME=$1
VERIFIER_TYPE=${2:-""} # Use empty string if no second argument provided
ADDITIONAL_ARGS=${3:-""} # Use empty string if no third argument provided

# Convert chain name to uppercase for env var lookup
CHAIN_UPPER=$(echo $CHAIN_NAME | tr '[:lower:]' '[:upper:]')

# Path to the deployment script
SCRIPT_PATH="script/deployParameters/${CHAIN_NAME}/DeployBase.s.sol:DeployBase"

echo "Running simulation for ${CHAIN_NAME}..."
# Run simulation first
if forge script ${SCRIPT_PATH} --slow --rpc-url ${CHAIN_NAME} -vvvv; then
    # If no verifier type is provided, exit after successful simulation
    if [ -z "$VERIFIER_TYPE" ]; then
        echo "Simulation completed successfully. No deployment performed (no verifier type provided)."
        exit 0
    fi
    
    # Get verifier URL from environment variables
    eval VERIFIER_URL=\$${CHAIN_UPPER}_ETHERSCAN_VERIFIER_URL

    # Set verifier arguments based on verifier type
    if [ "$VERIFIER_TYPE" = "blockscout" ]; then
        VERIFIER_ARG="--verifier blockscout --verifier-url ${VERIFIER_URL}"
    elif [ "$VERIFIER_TYPE" = "etherscan" ]; then
        VERIFIER_ARG="--verifier etherscan --verifier-url ${VERIFIER_URL}"
    else
        echo "Error: Unsupported verifier type. Use 'blockscout' or 'etherscan'"
        exit 1
    fi

    # Check if verifier URL is set
    if [ -z "$VERIFIER_URL" ]; then
        echo "Error: Verifier URL not found in environment variables. Please set ${CHAIN_UPPER}_ETHERSCAN_VERIFIER_URL"
        exit 1
    fi

    echo "Simulation successful! Proceeding with actual deployment..."
    
    # Run actual deployment with verification
    forge script ${SCRIPT_PATH} --slow --rpc-url ${CHAIN_NAME} --broadcast --verify ${VERIFIER_ARG} ${ADDITIONAL_ARGS} -vvvv
else
    echo "Simulation failed! Please check the output above for errors."
    exit 1
fi
