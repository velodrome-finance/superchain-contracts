// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract SendTokenIntegrationConcreteTest is TokenBridgeTest {
    uint256 public amount;
    uint32 public chainid;

    function test_WhenTheRequestedAmountIsZero() external {
        // It should revert with ZeroAmount
        vm.expectRevert(IUserTokenBridge.ZeroAmount.selector);
        rootTokenBridge.sendToken({_amount: amount, _chainid: chainid});
    }

    modifier whenTheRequestedAmountIsNotZero() {
        amount = TOKEN_1 * 1000;
        _;
    }

    function test_WhenTheRequestedChainIsTheCurrentChain() external whenTheRequestedAmountIsNotZero {
        // It should revert with InvalidChain
        chainid = root;
        vm.expectRevert(IUserTokenBridge.InvalidChain.selector);
        rootTokenBridge.sendToken({_amount: amount, _chainid: chainid});
    }

    modifier whenTheRequestedChainIsNotTheCurrentChain() {
        chainid = leaf;
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRequestedChainIsNotTheCurrentChain
    {
        // It should revert with IXERC20_NotHighEnoughLimits
        amount = 1;
        deal({token: address(rootXVelo), to: address(rootGauge), give: amount});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        rootTokenBridge.sendToken({_amount: amount, _chainid: chainid});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller() {
        setLimits({_rootMintingLimit: 0, _leafMintingLimit: amount});
        _;
    }

    function test_WhenTheAmountIsLargerThanTheBalanceOfCaller()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRequestedChainIsNotTheCurrentChain
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
        rootTokenBridge.sendToken({_amount: amount, _chainid: chainid});
    }

    function test_WhenTheAmountIsLessThanOrEqualToTheBalanceOfCaller()
        external
        whenTheRequestedAmountIsNotZero
        whenTheRequestedChainIsNotTheCurrentChain
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
            _destination: chainid,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenModule)),
            _value: ethAmount,
            _message: string(abi.encode(address(leafGauge), amount))
        });
        rootTokenBridge.sendToken{value: ethAmount}({_amount: amount, _chainid: chainid});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(address(rootTokenBridge).balance, 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenModule));
        emit IHLTokenBridge.ReceivedMessage({
            _origin: root,
            _sender: TypeCasts.addressToBytes32(address(leafTokenModule)),
            _value: 0,
            _message: string(abi.encode(address(leafGauge), amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
    }
}
