// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployStakingFixture} from "../../02_DeployStakingFixture.s.sol";

contract DeployStaking is DeployStakingFixture {
    function setUp() public override {
        _params = DeployStakingFixture.DeploymentParameters({
            router: 0x3a63171DD9BebF4D07BC782FECC7eb0b890C2A45,
            keeperAdmin: 0xb32Db5b848B837DC39EF20B4110dFAc7493e93ed,
            notifyAdmin: 0x3b5a0Fc12f8fd8B26d251F28258D1d172F930f8A,
            admin: 0x952cafa433aDa3075371F7F1d0e8C8175b13d0Ae,
            tokenRegistry: 0x8d9c67488c154286B9D4ccaC6c4CBF30589107a7,
            rewardToken: 0x4200000000000000000000000000000000000006,
            outputFilename: "bob.json"
        });
    }
}
