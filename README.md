# Superchain Contracts

## Deployment

Populate `foundry.toml` with the environment variables required for RPC and contract verification.

Run the following commands to check that the CreateX factory has the correct code. See [here](https://github.com/pcaversaccio/createx/blob/43adf407f1313c5975c7db106092c3b636323ef6/README.md?plain=1#L844) for more information. This is now done in the script, but feel free to check.

```
[[ $(cast keccak $(cast code 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed --rpc-url {RPC_URL})) == "0xbd8a7ea8cfca7b4e5f5041d7d4b17bc317c5ce42cfbc42066a00cf26b43eb53f" ]] && echo "Hash Matches" || echo "Hash Does Not Match"
```

Sample scripting commands, using DeployBase.s.sol as an example:

```
forge script script/deployParameters/optimism/DeployBase.s.sol:DeployBase --slow --rpc-url optimism -vvvv
```

With broadcast:

```
forge script script/deployParameters/optimism/DeployBase.s.sol:DeployBase --slow --rpc-url optimism --broadcast --verify -vvvv
```

If there is a verification failure, simply remove `--broadcast` and add `--resume`.

```
forge script script/deployParameters/optimism/DeployBase.s.sol:DeployBase --slow --rpc-url optimism --resume --verify -vvvv
```

## Verification

For etherscan-like verifications, fill out `foundry.toml`.

For blockscout verifications, append the following after `--verify`.

```
--verifier blockscout --verifier-url {BASE_URL}/api\?

e.g: 
--verifier blockscout --verifier-url https://explorer.mode.network/api\?
```