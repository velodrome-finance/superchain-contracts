// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployBaseFixture} from "../../01_DeployBaseFixture.s.sol";

contract DeployBase is DeployBaseFixture {
    function setUp() public override {
        _params = DeployBaseFixture.DeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            poolAdmin: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            pauser: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            feeManager: 0x607EbA808EF2685fAc3da68aB96De961fa8F3312,
            tokenAdmin: 0x0000000000000000000000000000000000000001,
            bridgeOwner: 0x0000000000000000000000000000000000000001,
            mailbox: 0x8358D8291e3bEDb04804975eEa0fe9fe0fAfB147,
            outputFilename: "bob.json"
        });
    }
}
