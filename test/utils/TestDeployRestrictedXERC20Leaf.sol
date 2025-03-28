// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployLeafRestrictedXERC20} from "script/deployRestrictedXERC20/01_DeployLeafRestrictedXERC20.sol";

contract TestDeployRestrictedXERC20Leaf is DeployLeafRestrictedXERC20 {
    constructor(DeployLeafRestrictedXERC20.RestrictedXERC20DeploymentParams memory _params_) {
        _params = _params_;
        isTest = true;
    }

    function setUp() public override {}
}
