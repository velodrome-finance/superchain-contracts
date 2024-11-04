// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployPartialBaseFixture} from "../../01_DeployPartialBaseFixture.s.sol";

contract DeployPartialBase is DeployPartialBaseFixture {
    function setUp() public override {
        _params = DeployPartialBaseFixture.DeploymentParameters({
            tokenAdmin: 0x0000000000000000000000000000000000000001,
            bridgeOwner: 0x0000000000000000000000000000000000000001,
            moduleOwner: 0x0000000000000000000000000000000000000001,
            mailbox: 0x8358D8291e3bEDb04804975eEa0fe9fe0fAfB147,
            inputFilename: "bob.json",
            outputFilename: "bob.json"
        });
        super.setUp();
    }
}
