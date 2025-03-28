// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployBridgesBaseFixture} from "../../01_DeployBridgesBaseFixture.s.sol";

contract DeployBridgesSoneium is DeployBridgesBaseFixture {
    function setUp() public override {
        _params = DeployBridgesBaseFixture.DeploymentParameters({
            moduleOwner: 0x3B39854f29D7Ec7110afe806312E1d9893F00C83,
            bridgeOwner: 0x3B39854f29D7Ec7110afe806312E1d9893F00C83,
            mailbox: 0x3a464f746D23Ab22155710f44dB16dcA53e0775E,
            outputFilename: "soneium.json"
        });
        super.setUp();
    }
}
