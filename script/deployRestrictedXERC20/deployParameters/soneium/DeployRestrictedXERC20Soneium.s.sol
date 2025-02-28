// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployLeafRestrictedXERC20} from "../../01_DeployLeafRestrictedXERC20.sol";

contract DeployRestrictedXERC20Soneium is DeployLeafRestrictedXERC20 {
    function setUp() public override {
        _params = DeployLeafRestrictedXERC20.RestrictedXERC20DeploymentParams({
            owner: 0x3B39854f29D7Ec7110afe806312E1d9893F00C83,
            mailbox: 0x3a464f746D23Ab22155710f44dB16dcA53e0775E,
            ism: address(0),
            voter: 0x97cDBCe21B6fd0585d29E539B1B99dAd328a1123,
            outputFilename: "soneium.json"
        });
        super.setUp();
    }
}
