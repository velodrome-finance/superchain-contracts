// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../TokenBridge.t.sol";

contract SendTokenIntegrationFuzzTest is TokenBridgeTest {
    uint256 public amount;
    address public recipient;

    modifier whenTheRequestedAmountIsNotZero() {
        _;
    }

    modifier whenTheRecipientIsNotAddressZero() {
        recipient = address(rootGauge);
        _;
    }

    modifier whenTheRequestedChainIsARegisteredChain() {
        vm.prank(users.owner);
        rootTokenBridge.registerChain({_chainid: leaf});

        vm.selectFork({forkId: leafId});
        vm.prank(users.owner);
        leafTokenBridge.registerChain({_chainid: root});
        vm.selectFork({forkId: rootId});
        _;
    }

    function testFuzz_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller(
        uint256 _bufferCap,
        uint256 _amount,
        address _recipient
    ) external whenTheRequestedAmountIsNotZero whenTheRequestedChainIsARegisteredChain {
        // It should revert with "RateLimited: buffer cap overflow"
        _bufferCap = bound(_bufferCap, rootXVelo.minBufferCap() + 1, MAX_BUFFER_CAP);
        amount = bound(_amount, _bufferCap / 2 + 2, type(uint256).max / 2); // increment by 2 to account for rounding
        vm.assume(_recipient != address(0));
        recipient = _recipient;

        deal({token: address(rootXVelo), to: address(rootGauge), give: amount});
        setLimits({_rootBufferCap: _bufferCap, _leafBufferCap: _bufferCap});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectRevert("RateLimited: buffer cap overflow");
        rootTokenBridge.sendToken({_recipient: recipient, _amount: amount, _chainid: leaf});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(uint256 _bufferCap, uint256 _amount) {
        _bufferCap = bound(_bufferCap, rootXVelo.minBufferCap() + 1, MAX_BUFFER_CAP);
        amount = bound(_amount, WEEK, _bufferCap / 2);
        setLimits({_rootBufferCap: _bufferCap, _leafBufferCap: _bufferCap});
        _;
    }

    function testFuzz_WhenTheAmountIsLargerThanTheBalanceOfCaller(uint256 _bufferCap, uint256 _amount, uint256 _balance)
        external
        whenTheRequestedAmountIsNotZero
        whenTheRecipientIsNotAddressZero
        whenTheRequestedChainIsARegisteredChain
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_bufferCap, _amount)
    {
        // It should revert with {ERC20InsufficientBalance}
        _balance = bound(_balance, 0, amount - 1);
        deal({token: address(rootXVelo), to: address(rootGauge), give: _balance});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(rootGauge), _balance, amount)
        );
        rootTokenBridge.sendToken({_recipient: recipient, _amount: amount, _chainid: leaf});
    }

    function testFuzz_WhenTheAmountIsLessThanOrEqualToTheBalanceOfCaller(
        uint256 _bufferCap,
        uint256 _amount,
        uint256 _balance,
        address _recipient
    )
        external
        whenTheRequestedAmountIsNotZero
        whenTheRequestedChainIsARegisteredChain
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_bufferCap, _amount)
    {
        // It burns the caller's tokens
        // It mints the tokens to the caller at the destination
        uint256 ethAmount = TOKEN_1;
        _balance = bound(_balance, amount, type(uint256).max / 2);
        vm.assume(_recipient != address(0));
        recipient = _recipient;

        vm.deal({account: address(rootGauge), newBalance: ethAmount});
        deal({token: address(rootXVelo), to: address(rootGauge), give: _balance});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootTokenBridge), value: amount});

        vm.expectEmit(address(rootTokenBridge));
        emit ITokenBridge.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootTokenBridge)),
            _value: ethAmount,
            _message: string(abi.encodePacked(recipient, amount))
        });
        rootTokenBridge.sendToken{value: ethAmount}({_recipient: recipient, _amount: amount, _chainid: leaf});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), _balance - amount);
        assertEq(address(rootTokenBridge).balance, 0);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: root,
            _sender: TypeCasts.addressToBytes32(address(leafTokenBridge)),
            _value: 0,
            _message: string(abi.encodePacked(recipient, amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(recipient), amount);
    }
}
