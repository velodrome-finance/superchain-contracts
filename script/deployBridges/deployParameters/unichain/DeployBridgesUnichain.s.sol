// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployBridgesBaseFixture} from "../../01_DeployBridgesBaseFixture.s.sol";

contract DeployBridgesUnichain is DeployBridgesBaseFixture {
    function setUp() public override {
        _params = DeployBridgesBaseFixture.DeploymentParameters({
            moduleOwner: 0xEe9aF44d60B03E14cF375363d0777c3c7328e081,
            bridgeOwner: 0xEe9aF44d60B03E14cF375363d0777c3c7328e081,
            mailbox: 0x3a464f746D23Ab22155710f44dB16dcA53e0775E,
            outputFilename: "unichain.json"
        });
        super.setUp();
    }
}
