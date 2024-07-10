// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract SetLimitsUnitFuzzTest is XERC20Test {
    function testFuzz_WhenCallerIsNotOwner(address _caller) external {
        // It should revert with OwnableUnauthorizedAccount
        vm.assume(_caller != address(0) && _caller != xVelo.owner());

        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
        xVelo.setLimits({_bridge: bridge, _mintingLimit: 0, _burningLimit: 0});
    }

    modifier whenCallerIsOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function testFuzz_WhenTheNewLimitIsGreaterThanHalfTheMaximumValueOfUint256(
        uint256 _mintingLimit,
        uint256 _burningLimit
    ) external whenCallerIsOwner {
        // It should revert with IXERC20_LimitsTooHigh
        _mintingLimit = bound(_mintingLimit, type(uint256).max / 2 + 1, type(uint256).max);
        _burningLimit = bound(_burningLimit, type(uint256).max / 2 + 1, type(uint256).max);

        vm.expectRevert(IXERC20.IXERC20_LimitsTooHigh.selector);
        xVelo.setLimits({_bridge: bridge, _mintingLimit: _mintingLimit, _burningLimit: 0});
        vm.expectRevert(IXERC20.IXERC20_LimitsTooHigh.selector);
        xVelo.setLimits({_bridge: bridge, _mintingLimit: 0, _burningLimit: _burningLimit});
    }

    modifier whenTheNewLimitIsLessThanOrEqualToHalfTheMaximumValueOfUint256() {
        _;
    }

    modifier whenTheNewLimitIsLessThanOrEqualToTheOldLimit() {
        _;
    }

    function testFuzz_WhenTheCurrentLimitIsLessThanOrEqualToTheDifferenceBetweenTheOldLimitAndTheNewLimit(
        uint256 _initialLimit,
        uint256 _usedLimit,
        uint256 _newLimit
    )
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

        // require: _usedLimit <= mintingLimit
        // require: current limit (i.e. mintingLimit - _usedLimit <= mintingLimit - newMintingLimit)
        //     i.e. newMintingLimit <= _usedLimit
        uint256 mintingLimit = bound(_initialLimit, 1, MAX_TOKENS);
        uint256 burningLimit = mintingLimit;
        _usedLimit = bound(_usedLimit, 1, mintingLimit);
        uint256 newMintingLimit = bound(_newLimit, 1, _usedLimit);
        uint256 newBurningLimit = newMintingLimit;

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
        xVelo.mint(bridge, _usedLimit);
        xVelo.burn(bridge, _usedLimit);

        vm.startPrank(users.owner);
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

    function test_WhenTheCurrentLimitIsGreaterThanTheDifferenceBetweenTheOldLimitAndTheNewLimit(
        uint256 _initialLimit,
        uint256 _usedLimit,
        uint256 _newLimit
    )
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

        // require: _usedLimit < mintingLimit
        // require: current limit (i.e. mintingLimit - _usedLimit > mintingLimit - newMintingLimit)
        //     i.e. newMintingLimit > _usedLimit
        // require: newMintingLimit <= mintingLimit (as this is required, _usedLimit must be smaller than mintingLimit)
        uint256 mintingLimit = bound(_initialLimit, 2, MAX_TOKENS);
        uint256 burningLimit = mintingLimit;
        _usedLimit = bound(_usedLimit, 1, mintingLimit - 1);
        uint256 newMintingLimit = bound(_newLimit, _usedLimit + 1, mintingLimit);
        uint256 newBurningLimit = newMintingLimit;

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
        xVelo.mint(bridge, _usedLimit);
        xVelo.burn(bridge, _usedLimit);

        vm.startPrank(users.owner);
        uint256 currentMintingLimit = mintingLimit - _usedLimit;
        uint256 currentBurningLimit = burningLimit - _usedLimit;
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

    function testFuzz_WhenTheNewLimitIsGreaterThanTheOldLimit(
        uint256 _initialLimit,
        uint256 _usedLimit,
        uint256 _newLimit
    ) external whenCallerIsOwner whenTheNewLimitIsLessThanOrEqualToHalfTheMaximumValueOfUint256 {
        // It should set a new max minting limit for the bridge
        // It should set the current minting limit for the bridge to the current limit plus the difference between the new limit and the old limit
        // It should set a new minting rate per second for the bridge
        // It should set the minting timestamp to the current timestamp
        // It should set a new max burning limit for the bridge
        // It should set the current burning limit for the bridge to the current limit plus the difference between the new limit and the old limit
        // It should set a new burning rate per second for the bridge
        // It should set the burning timestamp to the current timestamp
        // It should emit a {BridgeLimitsSet} event

        // require: _usedLimit <= mintingLimit
        // require: newMintingLimit > mintingLimit
        uint256 mintingLimit = bound(_initialLimit, 1, MAX_TOKENS - 1);
        uint256 burningLimit = mintingLimit;
        _usedLimit = bound(_usedLimit, 1, mintingLimit);
        uint256 newMintingLimit = bound(_newLimit, mintingLimit + 1, MAX_TOKENS);
        uint256 newBurningLimit = newMintingLimit;

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
        xVelo.mint(bridge, _usedLimit);
        xVelo.burn(bridge, _usedLimit);

        vm.startPrank(users.owner);
        // minting limits prior to update
        uint256 currentMintingLimit = mintingLimit - _usedLimit;
        uint256 currentBurningLimit = burningLimit - _usedLimit;
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
