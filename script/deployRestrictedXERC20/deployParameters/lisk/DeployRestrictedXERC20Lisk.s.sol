// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployLeafRestrictedXERC20} from "../../01_DeployLeafRestrictedXERC20.sol";

contract DeployRestrictedXERC20Lisk is DeployLeafRestrictedXERC20 {
    function setUp() public override {
        _params = DeployLeafRestrictedXERC20.RestrictedXERC20DeploymentParams({
            owner: 0xe915AEf46E1bd9b9eD2D9FE571AE9b5afbDE571b,
            mailbox: 0x2f2aFaE1139Ce54feFC03593FeE8AB2aDF4a85A7,
            ism: address(0),
            voter: 0x97cDBCe21B6fd0585d29E539B1B99dAd328a1123,
            outputFilename: "lisk.json"
        });
        super.setUp();
    }
}
