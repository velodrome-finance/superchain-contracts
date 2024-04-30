# Superchain Contracts

## Deployment

Populate `foundry.toml` with the environment variables required for RPC and contract verification.

Sample scripting commands, using DeployOptimism.s.sol as an example:

```
forge script script/deployParameters/DeployOptimism.s.sol:DeployOptimism --slow --rpc-url {chain} --vvvv
```

With broadcast:

```
forge script script/deployParameters/DeployOptimism.s.sol:DeployOptimism --slow --rpc-url {chain} --broadcast --verify --vvvv
```

If there is a verification failure, simply remove `--broadcast` and add `--resume`.

```
forge script script/deployParameters/DeployOptimism.s.sol:DeployOptimism --slow --rpc-url {chain} --resume --verify --vvvv
```
