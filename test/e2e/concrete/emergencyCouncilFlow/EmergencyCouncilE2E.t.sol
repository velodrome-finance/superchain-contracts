// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseE2EForkFixture.sol";

abstract contract EmergencyCouncilE2ETest is BaseE2EForkFixture {
    address gauge;

    function setUp() public virtual override {
        super.setUp();
        vm.selectFork({forkId: rootId});
        deal({token: address(weth), to: users.owner, give: MESSAGE_FEE});
        vm.prank(users.owner);
        weth.approve({spender: address(rootMessageBridge), value: MESSAGE_FEE});
    }

    function test_InitialState() public view {
        assertEq(emergencyCouncil.owner(), users.owner);
        assertEq(emergencyCouncil.voter(), address(mockVoter));
        assertEq(emergencyCouncil.votingEscrow(), address(mockEscrow));
    }
}
