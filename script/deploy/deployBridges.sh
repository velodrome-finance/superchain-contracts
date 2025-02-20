#!/bin/bash
set -e

# Help function
show_help() {
    echo "Usage: $0 <chain-name> [verifier-type] [additional_args]"
    echo
    echo "Creates bridge deployment files and optionally deploys them"
    echo
    echo "Arguments:"
    echo "  chain-name       Name of the chain to create deployment for (required)"
    echo "  verifier-type   Type of verifier to use (optional, 'blockscout' or 'etherscan')"
    echo "  additional_args  Additional arguments to pass to forge (optional)"
    echo
    echo "Examples:"
    echo "  $0 fraxtal                                           # Create deployment files only"
    echo "  $0 fraxtal blockscout                               # Deploy and verify on Blockscout"
    echo "  $0 fraxtal etherscan \"--with-gas-price 1000000000\"  # Deploy with custom gas price"
}

# Function to extract a parameter value from DeployBase.s.sol
extract_param() {
    local file=$1
    local param=$2
    grep -A 10 "DeploymentParameters" "$file" | grep "$param:" | awk -F': ' '{print $2}' | tr -d ',' | tr -d ' '
}

# Function to capitalize first letter
capitalize() {
    local str=$1
    echo "$(tr '[:lower:]' '[:upper:]' <<< ${str:0:1})${str:1}"
}

# Parse command line arguments
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

chain=$(echo "$1" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
VERIFIER_TYPE=${2:-""}  # Use empty string if no second argument provided
ADDITIONAL_ARGS=${3:-""}  # Use empty string if no third argument provided

echo "Processing chain: $chain"

# Capitalize chain name
capitalized_chain=$(capitalize "$chain")

# Setup paths
target_dir="script/deployBridges/deployParameters/${chain}"
template_file="script/deployBridges/deployTemplate/template/DeployBridgeTemplate.s.sol"
target_file="$target_dir/DeployBridges${capitalized_chain}.s.sol"
deploy_base_file="script/deployParameters/${chain}/DeployBase.s.sol"

# Check if DeployBase.s.sol exists for this chain
if [ ! -f "$deploy_base_file" ]; then
    echo "Error: $deploy_base_file not found"
    exit 1
fi

# Create new deployment file from template only if it doesn't exist
if [ ! -f "$target_file" ]; then
    echo "Creating deployment file for ${chain}..."
    mkdir -p "$target_dir"
    
    # Extract parameters from DeployBase.s.sol
    module_owner=$(extract_param "$deploy_base_file" "moduleOwner")
    bridge_owner=$(extract_param "$deploy_base_file" "bridgeOwner")
    mailbox=$(extract_param "$deploy_base_file" "mailbox")
    
    # Create new file from template with modifications
    sed -e "s/DeployBridgesTemplate/DeployBridges${capitalized_chain}/g" \
        -e "s/template.json/${chain}.json/g" \
        -e "s/moduleOwner: address(0)/moduleOwner: ${module_owner}/g" \
        -e "s/bridgeOwner: address(0)/bridgeOwner: ${bridge_owner}/g" \
        -e "s/mailbox: address(0)/mailbox: ${mailbox}/g" \
        "$template_file" > "$target_file"
    
    echo "Created $target_file"
else
    echo "Using existing deployment file at ${target_file}"
fi

# Path to the deployment script
SCRIPT_PATH="${target_file}:DeployBridges${capitalized_chain}"
echo $SCRIPT_PATH

echo "Running simulation for ${chain}..."
# Run simulation first
if forge script ${SCRIPT_PATH} --slow --rpc-url ${chain} -vvvv; then
    # If no verifier type is provided, exit after successful simulation
    if [ -z "$VERIFIER_TYPE" ]; then
        echo "Simulation completed successfully. No deployment performed (no verifier type provided)."
        exit 0
    fi
    
    # Set verifier arguments based on verifier type
    if [ "$VERIFIER_TYPE" = "blockscout" ]; then
        VERIFIER_ARG="--verifier blockscout"
    elif [ "$VERIFIER_TYPE" = "etherscan" ]; then
        VERIFIER_ARG="--verifier etherscan"
    else
        echo "Error: Unsupported verifier type. Use 'blockscout' or 'etherscan'"
        exit 1
    fi

    echo "Simulation successful! Proceeding with actual deployment..."
    
    # Run actual deployment with verification
    forge script ${SCRIPT_PATH} --slow --rpc-url ${chain} --broadcast --verify ${VERIFIER_ARG} ${ADDITIONAL_ARGS} -vvvv
else
    echo "Simulation failed! Please check the output above for errors."
    exit 1
fi
