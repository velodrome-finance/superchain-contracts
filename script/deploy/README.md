# Deployment Scripts

## Deploy Bridges

To deploy the new modules + token bridges, run the `deployBridges.sh` script. This script:
- Checks if the deployment files already exist in `deployBridges`
- If not, uses the `DeployBridgeTemplate.s.sol` as a template to create the new deployment files
- Then runs a simulation of the deployment
- If the simulation is successful, it will deploy the bridges to the chain

The parameters are taken from the corresponding `DeployBase.s.sol` file in `deployParameters`.

```bash
bash deployBridges.sh fraxtal etherscan
```