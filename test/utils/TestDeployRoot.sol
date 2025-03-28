// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployRootBaseFixture} from "script/root/01_DeployRootBaseFixture.s.sol";

contract TestDeployRoot is DeployRootBaseFixture {
    constructor(DeployRootBaseFixture.RootDeploymentParameters memory _params_) {
        _params = _params_;
        isTest = true;
    }

    function setUp() public override {}
}
