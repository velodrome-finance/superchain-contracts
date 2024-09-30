// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {DeployRootBaseFixture} from "../../root/01_DeployRootBaseFixture.s.sol";

contract DeployRootBase is DeployRootBaseFixture {
    function setUp() public override {
        _params = DeployRootBaseFixture.RootDeploymentParameters({
            weth: 0x4200000000000000000000000000000000000006,
            voter: 0x41C914ee0c7E1A5edCD0295623e6dC557B5aBf3C,
            velo: 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db,
            tokenAdmin: 0x0000000000000000000000000000000000000001,
            bridgeOwner: 0x0000000000000000000000000000000000000001,
            emergencyCouncilOwner: 0x0000000000000000000000000000000000000001,
            notifyAdmin: 0x0000000000000000000000000000000000000001,
            emissionAdmin: 0x0000000000000000000000000000000000000001,
            defaultCap: 100,
            mailbox: 0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D,
            outputFilename: "optimism.json"
        });
    }
}
