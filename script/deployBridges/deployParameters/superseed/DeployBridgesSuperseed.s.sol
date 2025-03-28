// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployBridgesBaseFixture} from "../../01_DeployBridgesBaseFixture.s.sol";

contract DeployBridgesSuperseed is DeployBridgesBaseFixture {
    function setUp() public override {
        _params = DeployBridgesBaseFixture.DeploymentParameters({
            moduleOwner: 0x6E5962C654488774406ffe04fc9A823546Fd94Bc,
            bridgeOwner: 0x6E5962C654488774406ffe04fc9A823546Fd94Bc,
            mailbox: 0x3a464f746D23Ab22155710f44dB16dcA53e0775E,
            outputFilename: "superseed.json"
        });
        super.setUp();
    }
}
