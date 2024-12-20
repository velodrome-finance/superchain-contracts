// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBaseFixture} from "script/01_DeployBaseFixture.s.sol";

contract TestDeployLeaf is DeployBaseFixture {
    constructor(DeployBaseFixture.DeploymentParameters memory _params_) {
        _params = _params_;
        isTest = true;
    }

    function setUp() public override {}
}
