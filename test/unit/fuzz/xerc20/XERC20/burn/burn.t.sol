// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../XERC20.t.sol";

contract BurnUnitFuzzTest is XERC20Test {
    function setUp() public override {
        super.setUp();

        vm.startPrank(users.owner);
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller(
        uint256 _mintLimit,
        uint256 _burnLimit
    ) external {
        // It should revert with IXERC20_NotHighEnoughLimits

        // require: _mintLimit > _burnLimit
        _burnLimit = bound(_burnLimit, 1, MAX_TOKENS - 1);
        _mintLimit = bound(_mintLimit, _burnLimit + 1, MAX_TOKENS);
        uint256 _mintAmount = _mintLimit;
        uint256 _burnAmount = _mintLimit;

        xVelo.setLimits({_bridge: bridge, _mintingLimit: _mintLimit, _burningLimit: _burnLimit});

        vm.startPrank(bridge);
        xVelo.mint(users.alice, _mintAmount);

        vm.startPrank(users.alice);
        xVelo.approve(bridge, _burnAmount);

        vm.startPrank(bridge);
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        xVelo.burn(bridge, _burnAmount);
    }

    function testFuzz_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(
        uint256 _burnLimit,
        uint256 _amountToBurn
    ) external {
        // It burns the requested amount of tokens
        // It decreases the current burning limit for the caller
        // It decreases the allowance of the caller by the requested amount
        // It should emit a {Transfer} event

        // require: _amountToBurn <= _burnLimit
        _burnLimit = bound(_burnLimit, 1, MAX_TOKENS);
        _amountToBurn = bound(_amountToBurn, 1, _burnLimit);

        uint256 mintingLimit = _amountToBurn;
        uint256 amountToMint = _amountToBurn;
        xVelo.setLimits({_bridge: bridge, _mintingLimit: mintingLimit, _burningLimit: _burnLimit});

        vm.startPrank(bridge);
        xVelo.mint(users.alice, amountToMint);

        vm.startPrank(users.alice);
        xVelo.approve(bridge, _amountToBurn);

        vm.expectEmit(address(xVelo));
        emit IERC20.Transfer({from: users.alice, to: address(0), value: _amountToBurn});
        vm.startPrank(bridge);
        xVelo.burn(users.alice, _amountToBurn);

        (IXERC20.BridgeParameters memory bpm, IXERC20.BridgeParameters memory bpb) = xVelo.bridges(bridge);
        assertEq(xVelo.balanceOf(bridge), 0);
        assertEq(xVelo.allowance(bridge, address(xVelo)), 0);
        assertEq(bpm.maxLimit, mintingLimit);
        assertEq(bpm.currentLimit, mintingLimit - amountToMint);
        assertEq(bpm.ratePerSecond, mintingLimit / DAY);
        assertEq(bpm.timestamp, block.timestamp);
        assertEq(bpb.maxLimit, _burnLimit);
        assertEq(bpb.currentLimit, _burnLimit - _amountToBurn);
        assertEq(bpb.ratePerSecond, _burnLimit / DAY);
        assertEq(bpb.timestamp, block.timestamp);
        assertEq(xVelo.mintingCurrentLimitOf(bridge), mintingLimit - amountToMint);
        assertEq(xVelo.mintingMaxLimitOf(bridge), mintingLimit);
        assertEq(xVelo.burningCurrentLimitOf(bridge), _burnLimit - _amountToBurn);
        assertEq(xVelo.burningMaxLimitOf(bridge), _burnLimit);
    }
}
