// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBaseFixture} from "../../01_DeployBaseFixture.s.sol";

contract DeployBase is DeployBaseFixture {
    function setUp() public override {
        _params = DeployBaseFixture.DeploymentParameters({
            weth: 0xFC00000000000000000000000000000000000006,
            poolAdmin: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            pauser: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            feeManager: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            tokenAdmin: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            bridgeOwner: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            moduleOwner: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            mailbox: 0x2f9DB5616fa3fAd1aB06cB2C906830BA63d135e3,
            outputFilename: "fraxtal.json"
        });
    }
}
