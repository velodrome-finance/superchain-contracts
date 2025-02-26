// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBaseFixture} from "../../01_DeployBaseFixture.s.sol";

contract DeployBase is DeployBaseFixture {
    function setUp() public override {
        _params = DeployBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0x6fF6F4485375C4D194c3C6F3FC15D53409697FcA,
            pauser: 0x6fF6F4485375C4D194c3C6F3FC15D53409697FcA,
            feeManager: 0x6fF6F4485375C4D194c3C6F3FC15D53409697FcA,
            tokenAdmin: 0x6fF6F4485375C4D194c3C6F3FC15D53409697FcA,
            bridgeOwner: 0x6fF6F4485375C4D194c3C6F3FC15D53409697FcA,
            moduleOwner: 0x6fF6F4485375C4D194c3C6F3FC15D53409697FcA,
            mailbox: 0x730f8a4128Fa8c53C777B62Baa1abeF94cAd34a9,
            outputFilename: "metal.json"
        });
    }
}
