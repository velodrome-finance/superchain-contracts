# Velodrome Superchain Contracts

## Installation

This repository depends on:

node v20 (recommend managing node versions using nvm)
foundry
yarn

To install & run:

```
yarn install
forge b

forge t -vv
```

## Deployment

Populate `foundry.toml` with the environment variables required for RPC and contract verification.

Run the following commands to check that the CreateX factory has the correct code. See [here](https://github.com/pcaversaccio/createx/blob/43adf407f1313c5975c7db106092c3b636323ef6/README.md?plain=1#L844) for more information. This is now done in the script, but feel free to check.

```
[[ $(cast keccak $(cast code 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed --rpc-url {RPC_URL})) == "0xbd8a7ea8cfca7b4e5f5041d7d4b17bc317c5ce42cfbc42066a00cf26b43eb53f" ]] && echo "Hash Matches" || echo "Hash Does Not Match"
```

Deploy Root contracts first:

```
forge script script/deployParameters/optimism/DeployRootBase.s.sol:DeployRootBase --slow --rpc-url optimism -vvvv
forge script script/deployParameters/optimism/DeployRootBase.s.sol:DeployRootBase --slow --rpc-url optimism --broadcast --verify -vvvv
```

Deploy Leaf contracts next:

```
forge script script/deployPartial/deployParameters/mode/DeployPartialBase.s.sol:DeployPartialBase --slow --rpc-url mode -vvvv
forge script script/deployPartial/deployParameters/mode/DeployPartialBase.s.sol:DeployPartialBase --slow --rpc-url mode --broadcast --verify --verifier blockscout --verifier-url https://explorer.mode.network/api\? -vvvv
```

```
forge script script/deployParameters/lisk/DeployBase.s.sol:DeployBase --slow --rpc-url lisk -vvvv
forge script script/deployParameters/lisk/DeployBase.s.sol:DeployBase --slow --rpc-url lisk --broadcast --verify --verifier blockscout --verifier-url https://blockscout.lisk.com/api\? -vvvv
```

Run the bash scripts (after updating them) to verify contracts.

```
bash script/verifyRoot.sh
bash script/verifyLeaf.sh
```

If there is a verification failure, simply remove `--broadcast` and add `--resume`.

```
forge script script/deployParameters/optimism/DeployBase.s.sol:DeployBase --slow --rpc-url optimism --resume --verify --verifier blockscout --verifier-url https://optimism.blockscout.com/api\? -vvvv
forge script script/deployParameters/optimism/DeployStaking.s.sol:DeployStaking --slow --rpc-url optimism --resume --verify --verifier blockscout --verifier-url https://optimism.blockscout.com/api\? -vvvv
```

## Verification

For etherscan-like verifications, fill out `foundry.toml`.

For blockscout verifications, append the following after `--verify`.

```
--verifier blockscout --verifier-url {BASE_URL}/api\?

e.g: 
--verifier blockscout --verifier-url https://explorer.mode.network/api\?
```

## xERC20

The xERC20 implementation in this repository adheres to the standard but deviates slightly in the following way:
- The lockbox has no support for native tokens. Other code related to this functionality has been removed.

## Licensing

This project follows the [Apache Foundation](https://infra.apache.org/licensing-howto.html)
guideline for licensing. See LICENSE and NOTICE files.
