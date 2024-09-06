// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract SendTokenIntegrationConcreteTest is TokenBridgeTest {
    uint256 public amount;

    function setUp() public override {
        super.setUp();
    }

    function test_WhenTheRequestedAmountIsZero() external {
        // It should revert with ZeroAmount
        vm.expectRevert(IUserTokenBridge.ZeroAmount.selector);
        rootTokenBridge.sendToken({_amount: amount, _chainid: leaf});
    }

    modifier whenTheRequestedAmountIsNotZero() {
        amount = TOKEN_1 * 1000;
        _;
    }

    function test_WhenTheRequestedChainIsNotARegisteredChain() external whenTheRequestedAmountIsNotZero {
        // It should revert with {NotRegistered}
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        rootTokenBridge.sendToken({_amount: amount, _chainid: leaf});
    }

    modifier whenTheRequestedChainIsARegisteredChain() {
        vm.prank(users.owner);
        rootTokenBridge.registerChain({_chainid: leaf});
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRequestedChainIsARegisteredChain
    {
        // It should revert with IXERC20_NotHighEnoughLimits
        amount = 1;
        deal({token: address(rootXVelo), to: address(rootGauge), give: amount});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        rootTokenBridge.sendToken({_amount: amount, _chainid: leaf});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller() {
        setLimits({_rootMintingLimit: 0, _leafMintingLimit: amount});
        _;
    }

    function test_WhenTheAmountIsLargerThanTheBalanceOfCaller()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRequestedChainIsARegisteredChain
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
    {
        // It should revert with ERC20InsufficientBalance
        deal({token: address(rootXVelo), to: address(rootGauge), give: amount - 1});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(rootGauge), amount - 1, amount
            )
        );
        rootTokenBridge.sendToken({_amount: amount, _chainid: leaf});
    }

    function test_WhenTheAmountIsLessThanOrEqualToTheBalanceOfCaller()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRequestedChainIsARegisteredChain
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
    {
        // It burns the caller's tokens
        // It mints the tokens to the caller at the destination
        uint256 ethAmount = TOKEN_1;
        vm.deal({account: address(rootGauge), newBalance: ethAmount});
        deal({token: address(rootXVelo), to: address(rootGauge), give: amount});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectEmit(address(rootTokenModule));
        emit IHLTokenBridge.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenModule)),
            _value: ethAmount,
            _message: string(abi.encode(address(leafGauge), amount))
        });
        rootTokenBridge.sendToken{value: ethAmount}({_amount: amount, _chainid: leaf});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(address(rootTokenBridge).balance, 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenModule));
        emit IHLHandler.ReceivedMessage({
            _origin: root,
            _sender: TypeCasts.addressToBytes32(address(leafTokenModule)),
            _value: 0,
            _message: string(abi.encode(address(leafGauge), amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
    }
}
