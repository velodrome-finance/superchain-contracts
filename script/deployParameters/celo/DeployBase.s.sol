// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBaseFixture} from "../../01_DeployBaseFixture.s.sol";

contract DeployBase is DeployBaseFixture {
    function setUp() public override {
        _params = DeployBaseFixture.DeploymentParameters({
            weth: address(0),
            poolAdmin: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            pauser: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            feeManager: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            tokenAdmin: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            bridgeOwner: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            moduleOwner: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            mailbox: 0x50da3B3907A08a24fe4999F4Dcf337E8dC7954bb,
            outputFilename: "celo.json"
        });
    }
}
