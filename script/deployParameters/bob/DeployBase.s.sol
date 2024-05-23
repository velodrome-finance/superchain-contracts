// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBaseFixture} from "../../01_DeployBaseFixture.s.sol";

contract DeployBase is DeployBaseFixture {
    address[] public whitelistedTokens = new address[](0);

    function setUp() public override {
        whitelistedTokens.push(0x4200000000000000000000000000000000000006);

        _params = DeployBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            pauser: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            feeManager: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            whitelistAdmin: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            whitelistedTokens: whitelistedTokens,
            outputFilename: "bob.json"
        });
    }
}
