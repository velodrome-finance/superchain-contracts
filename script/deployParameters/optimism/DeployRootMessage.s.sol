// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployRootMessageFixture} from "../../01_DeployRootMessageFixture.s.sol";

contract DeployRootMessage is DeployRootMessageFixture {
    function setUp() public override {
        _params = DeployRootMessageFixture.RootDeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            voter: 0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C,
            votingEscrow: 0xFAf8FD17D9840595845582fCB047DF13f006787d,
            velo: 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db,
            factoryRegistry: 0xF4c67CdEAaB8360370F41514d06e32CcD8aA1d7B,
            tokenAdmin: 0x0000000000000000000000000000000000000001,
            bridgeOwner: 0x0000000000000000000000000000000000000001,
            emergencyCouncilOwner: 0x0000000000000000000000000000000000000001,
            notifyAdmin: 0x0000000000000000000000000000000000000001,
            mailbox: 0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D,
            outputFilename: "optimism.json"
        });
    }
}
