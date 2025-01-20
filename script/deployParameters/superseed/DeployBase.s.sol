// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBaseFixture} from "../../01_DeployBaseFixture.s.sol";

contract DeployBase is DeployBaseFixture {
    function setUp() public override {
        _params = DeployBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0x6E5962C654488774406ffe04fc9A823546Fd94Bc,
            pauser: 0x6E5962C654488774406ffe04fc9A823546Fd94Bc,
            feeManager: 0x6E5962C654488774406ffe04fc9A823546Fd94Bc,
            tokenAdmin: 0x6E5962C654488774406ffe04fc9A823546Fd94Bc,
            bridgeOwner: 0x6E5962C654488774406ffe04fc9A823546Fd94Bc,
            moduleOwner: 0x6E5962C654488774406ffe04fc9A823546Fd94Bc,
            mailbox: 0x3a464f746D23Ab22155710f44dB16dcA53e0775E,
            outputFilename: "superseed.json"
        });
    }
}
