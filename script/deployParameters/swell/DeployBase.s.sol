// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBaseFixture} from "../../01_DeployBaseFixture.s.sol";

contract DeployBase is DeployBaseFixture {
    function setUp() public override {
        _params = DeployBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            pauser: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            feeManager: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            tokenAdmin: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            bridgeOwner: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            moduleOwner: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            mailbox: 0x3a464f746D23Ab22155710f44dB16dcA53e0775E,
            outputFilename: "swell.json"
        });
    }
}
