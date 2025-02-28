// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployRootRestrictedXERC20} from "../../01_DeployRootRestrictedXERC20.sol";

contract DeployRootRestrictedXERC20Base is DeployRootRestrictedXERC20 {
    function setUp() public override {
        _params = DeployRootRestrictedXERC20.RestrictedXERC20DeploymentParams({
            owner: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            incentiveToken: 0x4200000000000000000000000000000000000042, // OP token on Optimism
            module: 0x2BbA7515F7cF114B45186274981888D8C2fBA15E, // optimism v2 message module
            weth: 0x4200000000000000000000000000000000000006, // WETH on Optimism
            ism: address(0),
            outputFilename: "optimism.json"
        });
        super.setUp();
    }
}
