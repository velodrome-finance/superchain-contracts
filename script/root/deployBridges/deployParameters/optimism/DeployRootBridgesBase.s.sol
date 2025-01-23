// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import {DeployRootBridgesBaseFixture} from "../../01_DeployRootBridgesBaseFixture.s.sol";

contract DeployRootBridgesBase is DeployRootBridgesBaseFixture {
    function setUp() public override {
        _params = DeployRootBridgesBaseFixture.RootDeploymentParameters({
            bridgeOwner: 0xBA4BB89f4d1E66AA86B60696534892aE0cCf91F5,
            mailbox: 0xd4C1905BB1D26BC93DAC913e13CaCC278CdCC80D,
            outputFilename: "optimism.json"
        });
        super.setUp();
    }
}
