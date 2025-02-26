// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBaseFixture} from "../../01_DeployBaseFixture.s.sol";

contract DeployBase is DeployBaseFixture {
    function setUp() public override {
        _params = DeployBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0xEe9aF44d60B03E14cF375363d0777c3c7328e081,
            pauser: 0xEe9aF44d60B03E14cF375363d0777c3c7328e081,
            feeManager: 0xEe9aF44d60B03E14cF375363d0777c3c7328e081,
            tokenAdmin: 0xEe9aF44d60B03E14cF375363d0777c3c7328e081,
            bridgeOwner: 0xEe9aF44d60B03E14cF375363d0777c3c7328e081,
            moduleOwner: 0xEe9aF44d60B03E14cF375363d0777c3c7328e081,
            mailbox: 0x3a464f746D23Ab22155710f44dB16dcA53e0775E,
            outputFilename: "unichain.json"
        });
    }
}
