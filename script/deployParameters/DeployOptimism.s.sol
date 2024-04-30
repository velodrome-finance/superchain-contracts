// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBase} from "../01_DeployBase.s.sol";

contract DeployOptimism is DeployBase {
    function setUp() public override {
        _params = DeployBase.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0x0000000000000000000000000000000000000001,
            pauser: 0x0000000000000000000000000000000000000001,
            feeManager: 0x0000000000000000000000000000000000000001,
            outputFilename: "Optimism.json"
        });
    }
}
