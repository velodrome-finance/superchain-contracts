// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployBridgesBaseFixture} from "../../01_DeployBridgesBaseFixture.s.sol";

contract DeployBridgesSwell is DeployBridgesBaseFixture {
    function setUp() public override {
        _params = DeployBridgesBaseFixture.DeploymentParameters({
            moduleOwner: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            bridgeOwner: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            mailbox: 0x3a464f746D23Ab22155710f44dB16dcA53e0775E,
            outputFilename: "swell.json"
        });
        super.setUp();
    }
}
