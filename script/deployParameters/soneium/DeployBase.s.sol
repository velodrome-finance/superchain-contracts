// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBaseFixture} from "../../01_DeployBaseFixture.s.sol";

contract DeployBase is DeployBaseFixture {
    function setUp() public override {
        _params = DeployBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0x3B39854f29D7Ec7110afe806312E1d9893F00C83,
            pauser: 0x3B39854f29D7Ec7110afe806312E1d9893F00C83,
            feeManager: 0x3B39854f29D7Ec7110afe806312E1d9893F00C83,
            tokenAdmin: 0x3B39854f29D7Ec7110afe806312E1d9893F00C83,
            bridgeOwner: 0x3B39854f29D7Ec7110afe806312E1d9893F00C83,
            moduleOwner: 0x3B39854f29D7Ec7110afe806312E1d9893F00C83,
            mailbox: 0x3a464f746D23Ab22155710f44dB16dcA53e0775E,
            outputFilename: "soneium.json"
        });
    }
}
