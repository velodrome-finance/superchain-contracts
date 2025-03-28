// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployLeafRestrictedXERC20} from "../../01_DeployLeafRestrictedXERC20.sol";

contract DeployRestrictedXERC20Metal is DeployLeafRestrictedXERC20 {
    function setUp() public override {
        _params = DeployLeafRestrictedXERC20.RestrictedXERC20DeploymentParams({
            owner: 0x6fF6F4485375C4D194c3C6F3FC15D53409697FcA,
            mailbox: 0x730f8a4128Fa8c53C777B62Baa1abeF94cAd34a9,
            ism: address(0),
            voter: 0x97cDBCe21B6fd0585d29E539B1B99dAd328a1123,
            outputFilename: "metal.json"
        });
        super.setUp();
    }
}
