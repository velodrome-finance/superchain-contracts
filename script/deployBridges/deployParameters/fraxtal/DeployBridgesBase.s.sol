// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployBridgesBaseFixture} from "../../01_DeployBridgesBaseFixture.s.sol";

contract DeployBridgesBase is DeployBridgesBaseFixture {
    function setUp() public override {
        _params = DeployBridgesBaseFixture.DeploymentParameters({
            moduleOwner: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            bridgeOwner: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            mailbox: 0x2f9DB5616fa3fAd1aB06cB2C906830BA63d135e3,
            outputFilename: "fraxtal.json"
        });
        super.setUp();
    }
}
