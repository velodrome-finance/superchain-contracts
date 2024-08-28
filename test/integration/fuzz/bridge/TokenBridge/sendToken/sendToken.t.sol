// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract SendTokenIntegrationFuzzTest is TokenBridgeTest {
    uint256 public amount;
    uint32 public chainid;

    modifier whenTheRequestedAmountIsNotZero() {
        _;
    }

    modifier whenTheRequestedChainIsNotTheCurrentChain() {
        chainid = leaf;
        _;
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller(
        uint256 _burningLimit,
        uint256 _amount
    ) external whenTheRequestedAmountIsNotZero whenTheRequestedChainIsNotTheCurrentChain {
        // It should revert with IXERC20_NotHighEnoughLimits
        _burningLimit = bound(_burningLimit, WEEK, type(uint256).max / 2 - 1);
        amount = bound(_amount, _burningLimit + 1, type(uint256).max / 2);

        deal({token: address(rootXVelo), to: address(rootGauge), give: amount});
        setLimits({_rootMintingLimit: 0, _leafMintingLimit: _burningLimit});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        rootTokenBridge.sendToken({_amount: amount, _chainid: chainid});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(uint256 _burningLimit, uint256 _amount) {
        _burningLimit = bound(_burningLimit, WEEK, type(uint256).max / 2);
        amount = bound(_amount, WEEK, _burningLimit);
        setLimits({_rootMintingLimit: 0, _leafMintingLimit: _burningLimit});
        _;
    }

    function testFuzz_WhenTheAmountIsLargerThanTheBalanceOfCaller(
        uint256 _burningLimit,
        uint256 _amount,
        uint256 _balance
    )
        external
        whenTheRequestedAmountIsNotZero
        whenTheRequestedChainIsNotTheCurrentChain
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_burningLimit, _amount)
    {
        // It should revert with ERC20InsufficientBalance
        _balance = bound(_balance, 0, amount - 1);
        deal({token: address(rootXVelo), to: address(rootGauge), give: _balance});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(rootGauge), _balance, amount)
        );
        rootTokenBridge.sendToken({_amount: amount, _chainid: chainid});
    }

    function testFuzz_WhenTheAmountIsLessThanOrEqualToTheBalanceOfCaller(
        uint256 _burningLimit,
        uint256 _amount,
        uint256 _balance
    )
        external
        whenTheRequestedAmountIsNotZero
        whenTheRequestedChainIsNotTheCurrentChain
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_burningLimit, _amount)
    {
        // It burns the caller's tokens
        // It mints the tokens to the caller at the destination
        uint256 ethAmount = TOKEN_1;
        _balance = bound(_balance, amount, type(uint256).max / 2);
        vm.deal({account: address(rootGauge), newBalance: ethAmount});
        deal({token: address(rootXVelo), to: address(rootGauge), give: _balance});

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

        assertEq(rootXVelo.balanceOf(address(rootGauge)), _balance - amount);
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
