// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployLeafRestrictedXERC20} from "../../01_DeployLeafRestrictedXERC20.sol";

contract DeployRestrictedXERC20Base is DeployLeafRestrictedXERC20 {
    function setUp() public override {
        _params = DeployLeafRestrictedXERC20.RestrictedXERC20DeploymentParams({
            owner: 0xE6A41fE61E7a1996B59d508661e3f524d6A32075,
            mailbox: 0xeA87ae93Fa0019a82A727bfd3eBd1cFCa8f64f1D,
            ism: address(0),
            voter: 0x16613524e02ad97eDfeF371bC883F2F5d6C480A5,
            outputFilename: "base.json"
        });
        super.setUp();
    }
}
