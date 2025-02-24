// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployRootRestrictedXERC20} from "script/deployRestrictedXERC20/01_DeployRootRestrictedXERC20.sol";

contract TestDeployRestrictedXERC20Root is DeployRootRestrictedXERC20 {
    constructor(DeployRootRestrictedXERC20.RestrictedXERC20DeploymentParams memory _params_) {
        _params = _params_;
        isTest = true;
    }

    function setUp() public override {}
}
