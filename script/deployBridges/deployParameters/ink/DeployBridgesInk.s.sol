// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployBridgesBaseFixture} from "../../01_DeployBridgesBaseFixture.s.sol";

contract DeployBridgesInk is DeployBridgesBaseFixture {
    function setUp() public override {
        _params = DeployBridgesBaseFixture.DeploymentParameters({
            moduleOwner: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            bridgeOwner: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            mailbox: 0x7f50C5776722630a0024fAE05fDe8b47571D7B39,
            outputFilename: "ink.json"
        });
        super.setUp();
    }
}
