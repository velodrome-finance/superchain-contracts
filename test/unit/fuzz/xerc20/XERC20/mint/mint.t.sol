// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract MintUnitFuzzTest is XERC20Test {
    function setUp() public override {
        super.setUp();

        vm.startPrank(users.owner);
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimitOfCaller(
        uint256 _mintLimit,
        uint256 _mintAmount
    ) external {
        // It should revert with IXERC20_NotHighEnoughLimits

        // require: _mintAmount > _mintLimit
        _mintLimit = bound(_mintLimit, 1, MAX_TOKENS - 1);
        _mintAmount = bound(_mintAmount, _mintLimit + 1, MAX_TOKENS);

        xVelo.setLimits({_bridge: bridge, _mintingLimit: _mintLimit, _burningLimit: 0});

        vm.startPrank(bridge);
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        xVelo.mint(users.alice, _mintAmount);
    }

    function testFuzz_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimitOfCaller(
        uint256 _mintLimit,
        uint256 _mintAmount
    ) external {
        // It mints the requested amount of tokens to the user
        // It decreases the current minting limit for the caller
        // It should emit a {Transfer} event

        // require: _mintAmount <= _mintLimit
        _mintLimit = bound(_mintLimit, 1, MAX_TOKENS);
        _mintAmount = bound(_mintAmount, 1, _mintLimit);

        uint256 burningLimit = 0;
        xVelo.setLimits({_bridge: bridge, _mintingLimit: _mintLimit, _burningLimit: burningLimit});

        vm.startPrank(bridge);
        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: address(0), to: users.alice, value: _mintAmount});
        xVelo.mint(users.alice, _mintAmount);

        (IXERC20.BridgeParameters memory bpm, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        assertEq(xVelo.balanceOf(users.alice), _mintAmount);
        assertEq(bpm.maxLimit, _mintLimit);
        assertEq(bpm.currentLimit, _mintLimit - _mintAmount);
        assertEq(bpm.ratePerSecond, _mintLimit / DAY);
        assertEq(bpm.timestamp, block.timestamp);
        assertEq(bpb.maxLimit, burningLimit);
        assertEq(bpb.currentLimit, burningLimit);
        assertEq(bpb.ratePerSecond, burningLimit / DAY);
        assertEq(bpb.timestamp, block.timestamp);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), _mintLimit - _mintAmount);
        assertEq(xVelo.mintingMaxLimitOf(bridge), _mintLimit);
        assertEq(xVelo.burningCurrentLimitOf(bridge), burningLimit);
        assertEq(xVelo.burningMaxLimitOf(bridge), burningLimit);
    }
}
