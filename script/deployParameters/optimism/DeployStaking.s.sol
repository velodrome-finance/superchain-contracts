// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployStakingFixture} from "../../02_DeployStakingFixture.s.sol";

contract DeployStaking is DeployStakingFixture {
    function setUp() public override {
        _params = DeployStakingFixture.DeploymentParameters({
            router: 0x0000000000000000000000000000000000000001,
            keeperAdmin: 0x0000000000000000000000000000000000000001,
            notifyAdmin: 0x0000000000000000000000000000000000000001,
            admin: 0x0000000000000000000000000000000000000001,
            tokenRegistry: 0x0000000000000000000000000000000000000001,
            rewardToken: 0x0000000000000000000000000000000000000001,
            outputFilename: "Optimism.json"
        });
    }
}
