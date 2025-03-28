// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployBridgesBaseFixture} from "../../01_DeployBridgesBaseFixture.s.sol";

contract DeployBridgesTemplate is DeployBridgesBaseFixture {
    function setUp() public override {
        _params = DeployBridgesBaseFixture.DeploymentParameters({
            moduleOwner: address(0),
            bridgeOwner: address(0),
            mailbox: address(0),
            outputFilename: "template.json"
        });
        super.setUp();
    }
}
