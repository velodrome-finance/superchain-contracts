// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployBridgesBaseFixture} from "../../01_DeployBridgesBaseFixture.s.sol";

contract DeployBridgesBase is DeployBridgesBaseFixture {
    function setUp() public override {
        _params = DeployBridgesBaseFixture.DeploymentParameters({
            moduleOwner: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            bridgeOwner: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            mailbox: 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7,
            outputFilename: "lisk.json"
        });
        super.setUp();
    }
}
