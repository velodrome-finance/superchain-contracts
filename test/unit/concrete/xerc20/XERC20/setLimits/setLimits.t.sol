// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract SetLimitsUnitConcreteTest is XERC20Test {
    function setUp() public override {
        super.setUp();
    }

    function test_WhenCallerIsNotOwner() external {
        // It should revert with OwnableUnauthorizedAccount
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        xVelo.setLimits({_bridge: bridge, _mintingLimit: 0, _burningLimit: 0});
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenTheNewLimitIsGreaterThanHalfTheMaximumValueOfUint256() external whenCallerIsOwner {
        // It should revert with IXERC20_LimitsTooHigh
        vm.expectRevert(IXERC20.IXERC20_LimitsTooHigh.selector);
        xVelo.setLimits({_bridge: bridge, _mintingLimit: type(uint256).max / 2 + 1, _burningLimit: 0});
        vm.expectRevert(IXERC20.IXERC20_LimitsTooHigh.selector);
        xVelo.setLimits({_bridge: bridge, _mintingLimit: 0, _burningLimit: type(uint256).max / 2 + 1});
    }

    modifier whenTheNewLimitIsLessThanOrEqualToHalfTheMaximumValueOfUint256() {
        _;
    }

    modifier whenTheNewLimitIsLessThanOrEqualToTheOldLimit() {
        _;
    }

    function test_WhenTheCurrentLimitIsLessThanOrEqualToTheDifferenceBetweenTheOldLimitAndTheNewLimit()
        external
        whenCallerIsOwner
        whenTheNewLimitIsLessThanOrEqualToHalfTheMaximumValueOfUint256
        whenTheNewLimitIsLessThanOrEqualToTheOldLimit
    {
        // It should set a new max minting limit for the bridge
        // It should set the current minting limit for the bridge to zero
        // It should set a new minting rate per second for the bridge
        // It should set the minting timestamp to the current timestamp
        // It should set a new max burning limit for the bridge
        // It should set the current burning limit for the bridge to zero
        // It should set a new burning rate per second for the bridge
        // It should set the burning timestamp to the current timestamp
        // It should emit a {BridgeLimitsSet} event
        uint256 mintingLimit = 10_000 * TOKEN_1;
        uint256 burningLimit = 7_000 * TOKEN_1;
        uint256 usedLimit = 6_000 * TOKEN_1;

        vm.expectEmit(address(xVelo));
        emit IXERC20.BridgeLimitsSet({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: burningLimit});
        xVelo.setLimits({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: burningLimit});

        (IXERC20.BridgeParameters memory bpm, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        assertEq(bpm.maxLimit, mintingLimit);
        assertEq(bpm.currentLimit, mintingLimit);
        assertEq(bpm.ratePerSecond, mintingLimit / DAY);
        assertEq(bpm.timestamp, block.timestamp);
        assertEq(bpb.maxLimit, burningLimit);
        assertEq(bpb.currentLimit, burningLimit);
        assertEq(bpb.ratePerSecond, burningLimit / DAY);
        assertEq(bpb.timestamp, block.timestamp);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit);
        assertEq(xVelo.mintingMaxLimitOf(bridge), mintingLimit);
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit);
        assertEq(xVelo.burningMaxLimitOf(bridge), burningLimit);

        skip(DAY / 2);
        // use up minting capacity
        vm.startPrank(bridge);
        xVelo.mint(bridge, usedLimit);
        xVelo.burn(bridge, usedLimit);

        vm.startPrank(users.owner);
        // minting limits prior to update
        uint256 currentMintingLimit = mintingLimit - usedLimit; // 4_000 * TOKEN_1
        uint256 currentBurningLimit = burningLimit - usedLimit; // 1_000 * TOKEN_1
        // we set the new limit such that old limit - new limit = current limit
        // or: new limit = old limit - current limit
        uint256 newMintingLimit = mintingLimit - currentMintingLimit; // 6_000 * TOKEN_1;
        uint256 newBurningLimit = burningLimit - currentBurningLimit; // 6_000 * TOKEN_1;

        vm.expectEmit(address(xVelo));
        emit IXERC20.BridgeLimitsSet({_bridge: bridge, _mintingLimit: newMintingLimit, _burningLimit: newBurningLimit});
        xVelo.setLimits({_bridge: bridge, _mintingLimit: newMintingLimit, _burningLimit: newBurningLimit});

        (bpm, bpb) = xVelo.bridges(bridge);
        assertEq(bpm.maxLimit, newMintingLimit);
        assertEq(bpm.currentLimit, 0);
        assertEq(bpm.ratePerSecond, newMintingLimit / DAY);
        assertEq(bpm.timestamp, block.timestamp);
        assertEq(bpb.maxLimit, newBurningLimit);
        assertEq(bpb.currentLimit, 0);
        assertEq(bpb.ratePerSecond, newBurningLimit / DAY);
        assertEq(bpb.timestamp, block.timestamp);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), 0);
        assertEq(xVelo.mintingMaxLimitOf(bridge), newMintingLimit);
        assertEq(xVelo.burningCurrentLimitOf(bridge), 0);
        assertEq(xVelo.burningMaxLimitOf(bridge), newBurningLimit);
    }

    function test_WhenTheCurrentLimitIsGreaterThanTheDifferenceBetweenTheOldLimitAndTheNewLimit()
        external
        whenCallerIsOwner
        whenTheNewLimitIsLessThanOrEqualToHalfTheMaximumValueOfUint256
        whenTheNewLimitIsLessThanOrEqualToTheOldLimit
    {
        // It should set a new max minting limit for the bridge
        // It should set the current minting limit for the bridge to the current limit minus the difference between the old limit and the new limit
        // It should set a new minting rate per second for the bridge
        // It should set the minting timestamp to the current timestamp
        // It should set a new max burning limit for the bridge
        // It should set the current burning limit for the bridge to the current limit minus the difference between the old limit and the new limit
        // It should set a new burning rate per second for the bridge
        // It should set the burning timestamp to the current timestamp
        // It should emit a {BridgeLimitsSet} event
        uint256 mintingLimit = 10_000 * TOKEN_1;
        uint256 burningLimit = 7_000 * TOKEN_1;
        uint256 usedLimit = 6_000 * TOKEN_1;

        vm.expectEmit(address(xVelo));
        emit IXERC20.BridgeLimitsSet({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: burningLimit});
        xVelo.setLimits({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: burningLimit});

        (IXERC20.BridgeParameters memory bpm, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        assertEq(bpm.maxLimit, mintingLimit);
        assertEq(bpm.currentLimit, mintingLimit);
        assertEq(bpm.ratePerSecond, mintingLimit / DAY);
        assertEq(bpm.timestamp, block.timestamp);
        assertEq(bpb.maxLimit, burningLimit);
        assertEq(bpb.currentLimit, burningLimit);
        assertEq(bpb.ratePerSecond, burningLimit / DAY);
        assertEq(bpb.timestamp, block.timestamp);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit);
        assertEq(xVelo.mintingMaxLimitOf(bridge), mintingLimit);
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit);
        assertEq(xVelo.burningMaxLimitOf(bridge), burningLimit);

        skip(DAY / 2);
        // use up minting capacity
        vm.startPrank(bridge);
        xVelo.mint(bridge, usedLimit);
        xVelo.burn(bridge, usedLimit);

        vm.startPrank(users.owner);
        // minting limits prior to update
        uint256 currentMintingLimit = mintingLimit - usedLimit; // 4_000 * TOKEN_1
        uint256 currentBurningLimit = burningLimit - usedLimit; // 1_000 * TOKEN_1
        // we set the new limit such that old limit - new limit < current limit
        // or: new limit = old limit - current limit + 1
        uint256 newMintingLimit = mintingLimit - currentMintingLimit + 1; // 6_000 * TOKEN_1 + 1;
        uint256 newBurningLimit = burningLimit - currentBurningLimit + 1; // 6_000 * TOKEN_1 + 1;
        uint256 mintingDifference = mintingLimit - newMintingLimit;
        uint256 burningDifference = burningLimit - newBurningLimit;

        vm.expectEmit(address(xVelo));
        emit IXERC20.BridgeLimitsSet({_bridge: bridge, _mintingLimit: newMintingLimit, _burningLimit: newBurningLimit});
        xVelo.setLimits({_bridge: bridge, _mintingLimit: newMintingLimit, _burningLimit: newBurningLimit});

        (bpm, bpb) = xVelo.bridges(bridge);
        assertEq(bpm.maxLimit, newMintingLimit);
        assertEq(bpm.currentLimit, currentMintingLimit - mintingDifference);
        assertEq(bpm.ratePerSecond, newMintingLimit / DAY);
        assertEq(bpm.timestamp, block.timestamp);
        assertEq(bpb.maxLimit, newBurningLimit);
        assertEq(bpb.currentLimit, currentBurningLimit - burningDifference);
        assertEq(bpb.ratePerSecond, newBurningLimit / DAY);
        assertEq(bpb.timestamp, block.timestamp);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), currentMintingLimit - mintingDifference);
        assertEq(xVelo.mintingMaxLimitOf(bridge), newMintingLimit);
        assertEq(xVelo.burningCurrentLimitOf(bridge), currentBurningLimit - burningDifference);
        assertEq(xVelo.burningMaxLimitOf(bridge), newBurningLimit);
    }

    function test_WhenTheNewLimitIsGreaterThanTheOldLimit()
        external
        whenCallerIsOwner
        whenTheNewLimitIsLessThanOrEqualToHalfTheMaximumValueOfUint256
    {
        // It should set a new max minting limit for the bridge
        // It should set the current minting limit for the bridge to the current limit plus the difference between the new limit and the old limit
        // It should set a new minting rate per second for the bridge
        // It should set the minting timestamp to the current timestamp
        // It should set a new max burning limit for the bridge
        // It should set the current burning limit for the bridge to the current limit plus the difference between the new limit and the old limit
        // It should set a new burning rate per second for the bridge
        // It should set the burning timestamp to the current timestamp
        // It should emit a {BridgeLimitsSet} event
        uint256 mintingLimit = 10_000 * TOKEN_1;
        uint256 burningLimit = 5_000 * TOKEN_1;
        uint256 usedLimit = 2_500 * TOKEN_1;

        vm.expectEmit(address(xVelo));
        emit IXERC20.BridgeLimitsSet({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: burningLimit});
        xVelo.setLimits({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: burningLimit});

        (IXERC20.BridgeParameters memory bpm, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        assertEq(bpm.maxLimit, mintingLimit);
        assertEq(bpm.currentLimit, mintingLimit);
        assertEq(bpm.ratePerSecond, mintingLimit / DAY);
        assertEq(bpm.timestamp, block.timestamp);
        assertEq(bpb.maxLimit, burningLimit);
        assertEq(bpb.currentLimit, burningLimit);
        assertEq(bpb.ratePerSecond, burningLimit / DAY);
        assertEq(bpb.timestamp, block.timestamp);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit);
        assertEq(xVelo.mintingMaxLimitOf(bridge), mintingLimit);
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit);
        assertEq(xVelo.burningMaxLimitOf(bridge), burningLimit);

        skip(DAY / 2);
        // use up minting capacity
        vm.startPrank(bridge);
        xVelo.mint(bridge, usedLimit);
        xVelo.burn(bridge, usedLimit);

        vm.startPrank(users.owner);
        uint256 newMintingLimit = 20_000 * TOKEN_1;
        uint256 newBurningLimit = 10_000 * TOKEN_1;
        // minting limits prior to update
        uint256 currentMintingLimit = mintingLimit - usedLimit;
        uint256 currentBurningLimit = burningLimit - usedLimit;
        // difference between new and old limits
        uint256 mintingDifference = newMintingLimit - mintingLimit;
        uint256 burningDifference = newBurningLimit - burningLimit;

        vm.expectEmit(address(xVelo));
        emit IXERC20.BridgeLimitsSet({_bridge: bridge, _mintingLimit: newMintingLimit, _burningLimit: newBurningLimit});
        xVelo.setLimits({_bridge: bridge, _mintingLimit: newMintingLimit, _burningLimit: newBurningLimit});

        (bpm, bpb) = xVelo.bridges(bridge);
        assertEq(bpm.maxLimit, newMintingLimit);
        assertEq(bpm.currentLimit, currentMintingLimit + mintingDifference);
        assertEq(bpm.ratePerSecond, newMintingLimit / DAY);
        assertEq(bpm.timestamp, block.timestamp);
        assertEq(bpb.maxLimit, newBurningLimit);
        assertEq(bpb.currentLimit, currentBurningLimit + burningDifference);
        assertEq(bpb.ratePerSecond, newBurningLimit / DAY);
        assertEq(bpb.timestamp, block.timestamp);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), currentMintingLimit + mintingDifference);
        assertEq(xVelo.mintingMaxLimitOf(bridge), newMintingLimit);
        assertEq(xVelo.burningCurrentLimitOf(bridge), currentBurningLimit + burningDifference);
        assertEq(xVelo.burningMaxLimitOf(bridge), newBurningLimit);
    }
}
