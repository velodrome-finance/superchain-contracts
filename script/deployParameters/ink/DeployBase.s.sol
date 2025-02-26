// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBaseFixture} from "../../01_DeployBaseFixture.s.sol";

contract DeployBase is DeployBaseFixture {
    function setUp() public override {
        _params = DeployBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            pauser: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            feeManager: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            tokenAdmin: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            bridgeOwner: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            moduleOwner: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            mailbox: 0x7f50C5776722630a0024fAE05fDe8b47571D7B39,
            outputFilename: "ink.json"
        });
    }
}
