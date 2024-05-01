// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {Pool} from "src/pools/Pool.sol";
import {PoolFactory} from "src/pools/PoolFactory.sol";
import {Router} from "src/Router.sol";

abstract contract DeployBase is Script {
    struct DeploymentParameters {
        address weth;
        address poolAdmin;
        address pauser;
        address feeManager;
        string outputFilename;
    }

    DeploymentParameters internal _params;

    // deployed
    address public poolImplementation;
    PoolFactory public poolFactory;
    address public router;

    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.rememberKey(deployPrivateKey);

    function setUp() public virtual;

    function run() external {
        vm.startBroadcast(deployerAddress);
        poolImplementation = address(new Pool());
        poolFactory = new PoolFactory({
            _implementation: poolImplementation,
            _poolAdmin: _params.poolAdmin,
            _pauser: _params.pauser,
            _feeManager: _params.feeManager
        });

        router = address(new Router({_factory: address(poolFactory), _weth: _params.weth}));

        logParams();
        vm.stopBroadcast();
    }

    function logParams() internal view {
        console2.log("poolImplementation: ", poolImplementation);
        console2.log("poolFactory: ", address(poolFactory));
        console2.log("router: ", router);
    }

    function logOutput() internal {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses", _params.outputFilename));
        vm.writeJson(
            path,
            string(
                abi.encodePacked(
                    stdJson.serialize("", "poolImplementation", poolImplementation),
                    stdJson.serialize("", "poolFactory", address(poolFactory)),
                    stdJson.serialize("", "router", router)
                )
            )
        );
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }
}
