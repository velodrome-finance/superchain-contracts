// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "./XERC20.t.sol";
import {SigUtils} from "test/utils/SigUtils.sol";

contract xVeloUnitTest is XERC20Test {
    using SafeCast for uint256;

    uint128 public rateLimitPerSecond;
    uint112 public bufferCap;
    SigUtils public sigUtils;

    function setUp() public override {
        super.setUp();

        sigUtils = new SigUtils(xVelo.DOMAIN_SEPARATOR());

        bufferCap = (TOKEN_1 * 5_000).toUint112();
        rateLimitPerSecond = ((bufferCap / 2) / DAY).toUint128(); // replenish limits in 1 day

        vm.startPrank(users.owner);
        xVelo.addBridge(
            MintLimits.RateLimitMidPointInfo({
                bufferCap: bufferCap,
                bridge: bridge,
                rateLimitPerSecond: rateLimitPerSecond
            })
        );
    }

    function testSetup() public view {
        assertTrue(xVelo.DOMAIN_SEPARATOR() != bytes32(0), "domain separator not set");
        assertEq(xVelo.bufferCap(bridge), bufferCap, "incorrect bridge buffer cap");
        assertEq(xVelo.bufferCap(bridge), xVelo.mintingMaxLimitOf(bridge), "incorrect bridge mintingMaxLimitOf");
        assertEq(xVelo.bufferCap(bridge), xVelo.burningMaxLimitOf(bridge), "incorrect bridge burningMaxLimitOf");
        assertEq(xVelo.buffer(bridge), bufferCap / 2, "incorrect bridge buffer");
        assertEq(xVelo.buffer(bridge), xVelo.mintingCurrentLimitOf(bridge), "incorrect bridge mintingCurrentLimitOf");
        assertEq(
            xVelo.bufferCap(bridge) - xVelo.buffer(bridge),
            xVelo.burningCurrentLimitOf(bridge),
            "incorrect bridge burningCurrentLimitOf"
        );
        assertEq(xVelo.rateLimitPerSecond(bridge), rateLimitPerSecond, "incorrect bridge rate limit per second");
    }

    function testLockboxCanMint(uint112 mintAmount) public {
        mintAmount = uint112(_bound(mintAmount, 1, MAX_TOKENS));

        _lockboxCanMint(mintAmount);
    }

    function testLockBoxCanBurn(uint112 burnAmount) public {
        burnAmount = uint112(_bound(burnAmount, 1, MAX_TOKENS));

        testLockboxCanMint(burnAmount);
        _lockboxCanBurn(burnAmount);
    }

    function testLockBoxCanMintBurn(uint112 mintAmount) public {
        mintAmount = uint112(_bound(mintAmount, 1, MAX_TOKENS));

        _lockboxCanMint(mintAmount);
        _lockboxCanBurn(mintAmount);

        assertEq(xVelo.totalSupply(), 0, "incorrect total supply");
    }

    /// ACL

    function testSetBufferCapOwnerSucceeds(uint112 _bufferCap) public {
        _bufferCap = uint112(_bound(_bufferCap, xVelo.MIN_BUFFER_CAP() + 1, MAX_BUFFER_CAP));

        xVelo.setBufferCap(bridge, _bufferCap);
        assertEq(xVelo.bufferCap(bridge), _bufferCap, "incorrect buffer cap");
    }

    function testSetRateLimitPerSecondOwnerSucceeds(uint128 newRateLimitPerSecond) public {
        newRateLimitPerSecond = uint128(_bound(newRateLimitPerSecond, 1, xVelo.MAX_RATE_LIMIT_PER_SECOND()));
        xVelo.setRateLimitPerSecond(bridge, newRateLimitPerSecond);

        assertEq(xVelo.rateLimitPerSecond(bridge), newRateLimitPerSecond, "incorrect rate limit per second");
    }

    /// add a new bridge and rate limit
    function testAddNewBridgeOwnerSucceeds(address newBridge, uint128 newRateLimitPerSecond, uint112 newBufferCap)
        public
    {
        xVelo.removeBridge(bridge);

        if (xVelo.buffer(newBridge) != 0) {
            xVelo.removeBridge(newBridge);
        }

        /// bound input so bridge is not zero address
        newBridge = address(uint160(_bound(uint256(uint160(newBridge)), 1, type(uint160).max)));

        newRateLimitPerSecond = uint128(_bound(newRateLimitPerSecond, 1, xVelo.MAX_RATE_LIMIT_PER_SECOND()));
        newBufferCap = uint112(_bound(newBufferCap, xVelo.MIN_BUFFER_CAP() + 1, MAX_BUFFER_CAP));

        MintLimits.RateLimitMidPointInfo memory bridgeConfig = MintLimits.RateLimitMidPointInfo({
            bridge: newBridge,
            bufferCap: newBufferCap,
            rateLimitPerSecond: newRateLimitPerSecond
        });

        xVelo.addBridge(bridgeConfig);

        assertEq(xVelo.rateLimitPerSecond(newBridge), newRateLimitPerSecond, "incorrect rate limit per second");

        assertEq(xVelo.bufferCap(newBridge), newBufferCap, "incorrect buffer cap");
    }

    function testRemoveBridgeOwnerSucceeds() public {
        xVelo.removeBridge(bridge);

        assertEq(xVelo.bufferCap(bridge), 0, "incorrect buffer cap");
        assertEq(xVelo.rateLimitPerSecond(bridge), 0, "incorrect rate limit per second");
        assertEq(xVelo.buffer(bridge), 0, "incorrect buffer");
    }

    function testDepleteBufferBridgeSucceeds() public {
        address newBridge = address(0xeeeee);
        uint128 _rateLimitPerSecond = uint128(xVelo.MAX_RATE_LIMIT_PER_SECOND());
        uint112 _bufferCap = 20_000_000 * 1e18;

        testAddNewBridgeOwnerSucceeds(newBridge, _rateLimitPerSecond, _bufferCap);

        uint256 amount = 100_000 * 1e18;

        xVelo.approve(newBridge, amount);

        vm.startPrank(newBridge);
        xVelo.mint(users.owner, amount);

        uint256 buffer = xVelo.buffer(newBridge);
        uint256 userStartingBalance = xVelo.balanceOf(users.owner);
        uint256 startingTotalSupply = xVelo.totalSupply();

        xVelo.burn(users.owner, amount);

        assertEq(xVelo.buffer(newBridge), buffer + amount, "incorrect buffer amount");
        assertEq(xVelo.balanceOf(users.owner), userStartingBalance - amount, "incorrect user balance");
        assertEq(xVelo.allowance(users.owner, newBridge), 0, "incorrect allowance");
        assertEq(startingTotalSupply - xVelo.totalSupply(), amount, "incorrect total supply");
    }

    function testReplenishBufferBridgeSucceeds() public {
        address newBridge = address(0xeeeee);
        uint128 _rateLimitPerSecond = uint128(xVelo.MAX_RATE_LIMIT_PER_SECOND());
        uint112 _bufferCap = 20_000_000 * 1e18;

        testAddNewBridgeOwnerSucceeds(newBridge, _rateLimitPerSecond, _bufferCap);

        uint256 amount = 100_000 * 1e18;

        uint256 buffer = xVelo.buffer(newBridge);
        uint256 userStartingBalance = xVelo.balanceOf(users.owner);
        uint256 startingTotalSupply = xVelo.totalSupply();

        vm.startPrank(newBridge);
        xVelo.mint(users.owner, amount);

        assertEq(xVelo.buffer(newBridge), buffer - amount, "incorrect buffer amount");
        assertEq(xVelo.totalSupply() - startingTotalSupply, amount, "incorrect total supply");
        assertEq(xVelo.balanceOf(users.owner) - userStartingBalance, amount, "incorrect user balance");
    }

    function testReplenishBufferBridgeByZeroFails() public {
        address newBridge = address(0xeeeee);
        uint128 _rateLimitPerSecond = uint128(xVelo.MAX_RATE_LIMIT_PER_SECOND());
        uint112 _bufferCap = 20_000_000 * 1e18;

        testAddNewBridgeOwnerSucceeds(newBridge, _rateLimitPerSecond, _bufferCap);

        vm.startPrank(newBridge);
        vm.expectRevert("MintLimits: deplete amount cannot be 0");
        xVelo.mint(users.owner, 0);
    }

    function testDepleteBufferBridgeByZeroFails() public {
        address newBridge = address(0xeeeee);
        uint128 _rateLimitPerSecond = uint128(xVelo.MAX_RATE_LIMIT_PER_SECOND());
        uint112 _bufferCap = 20_000_000 * 1e18;

        testAddNewBridgeOwnerSucceeds(newBridge, _rateLimitPerSecond, _bufferCap);

        vm.startPrank(newBridge);
        vm.expectRevert("MintLimits: replenish amount cannot be 0");
        xVelo.burn(users.owner, 0);
    }

    function testDepleteBufferNonBridgeByOneFails() public {
        address newBridge = address(0xeeeee);
        xVelo.approve(newBridge, 1);

        vm.startPrank(newBridge);
        vm.expectRevert("RateLimited: buffer cap overflow");
        xVelo.burn(users.owner, 1);
    }

    function testReplenishBufferNonBridgeByOneFails() public {
        address newBridge = address(0xeeeee);

        vm.startPrank(newBridge);
        vm.expectRevert("RateLimited: rate limit hit");
        xVelo.mint(users.owner, 1);
    }

    function testApprove(uint256 amount) public {
        xVelo.approve(bridge, amount);

        assertEq(xVelo.allowance(users.owner, bridge), amount, "incorrect allowance");
    }

    function testPermit(uint256 amount) public {
        address spender = bridge;
        uint256 deadline = 5000000000; // timestamp far in the future
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);

        SigUtils.Permit memory permit =
            SigUtils.Permit({owner: owner, spender: spender, value: amount, nonce: 0, deadline: deadline});

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        xVelo.permit(owner, spender, amount, deadline, v, r, s);

        assertEq(xVelo.allowance(owner, spender), amount, "incorrect allowance");
        assertEq(xVelo.nonces(owner), 1, "incorrect nonce");
    }

    /// --------------------------------------------------------
    /// --------------------------------------------------------
    /// ----------- Internal testing helper functions ----------
    /// --------------------------------------------------------
    /// --------------------------------------------------------

    function _lockboxCanBurn(uint112 burnAmount) internal {
        uint256 startingTotalSupply = xVelo.totalSupply();
        uint256 startingVeloBalance = rewardToken.balanceOf(users.owner);
        uint256 startingXVeloBalance = xVelo.balanceOf(users.owner);

        xVelo.approve(address(lockbox), burnAmount);
        lockbox.withdraw(burnAmount);

        uint256 endingTotalSupply = xVelo.totalSupply();
        uint256 endingVeloBalance = rewardToken.balanceOf(users.owner);
        uint256 endingXVeloBalance = xVelo.balanceOf(users.owner);

        assertEq(startingTotalSupply - endingTotalSupply, burnAmount, "incorrect burn amount to totalSupply");
        assertEq(endingVeloBalance - startingVeloBalance, burnAmount, "incorrect burn amount to well balance");
        assertEq(startingXVeloBalance - endingXVeloBalance, burnAmount, "incorrect burn amount to xwell balance");
    }

    function _lockboxCanMint(uint112 mintAmount) internal {
        deal(address(rewardToken), users.owner, mintAmount);
        rewardToken.approve(address(lockbox), mintAmount);

        uint256 startingTotalSupply = xVelo.totalSupply();
        uint256 startingVeloBalance = rewardToken.balanceOf(users.owner);
        uint256 startingXVeloBalance = xVelo.balanceOf(users.owner);

        lockbox.deposit(mintAmount);

        uint256 endingTotalSupply = xVelo.totalSupply();
        uint256 endingVeloBalance = rewardToken.balanceOf(users.owner);
        uint256 endingXVeloBalance = xVelo.balanceOf(users.owner);

        assertEq(endingTotalSupply - startingTotalSupply, mintAmount, "incorrect mint amount to totalSupply");
        assertEq(startingVeloBalance - endingVeloBalance, mintAmount, "incorrect mint amount to well balance");
        assertEq(endingXVeloBalance - startingXVeloBalance, mintAmount, "incorrect mint amount to xwell balance");
    }
}
