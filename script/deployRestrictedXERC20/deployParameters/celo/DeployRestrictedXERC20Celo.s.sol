// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployLeafRestrictedXERC20} from "../../01_DeployLeafRestrictedXERC20.sol";

contract DeployRestrictedXERC20Celo is DeployLeafRestrictedXERC20 {
    function setUp() public override {
        _params = DeployLeafRestrictedXERC20.RestrictedXERC20DeploymentParams({
            owner: 0x9d5064e4910410f56626d2D187758d83D8e85860,
            mailbox: 0x50da3B3907A08a24fe4999F4Dcf337E8dC7954bb,
            ism: address(0),
            voter: 0x97cDBCe21B6fd0585d29E539B1B99dAd328a1123,
            outputFilename: "celo.json"
        });
        super.setUp();
    }
}
