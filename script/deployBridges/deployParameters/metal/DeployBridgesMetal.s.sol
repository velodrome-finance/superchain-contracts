// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployBridgesBaseFixture} from "../../01_DeployBridgesBaseFixture.s.sol";

contract DeployBridgesMetal is DeployBridgesBaseFixture {
    function setUp() public override {
        _params = DeployBridgesBaseFixture.DeploymentParameters({
            moduleOwner: 0x6fF6F4485375C4D194c3C6F3FC15D53409697FcA,
            bridgeOwner: 0x6fF6F4485375C4D194c3C6F3FC15D53409697FcA,
            mailbox: 0x730f8a4128Fa8c53C777B62Baa1abeF94cAd34a9,
            outputFilename: "metal.json"
        });
        super.setUp();
    }
}
