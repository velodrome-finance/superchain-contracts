// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../Bridge.t.sol";

contract SendTokenIntegrationFuzzTest is BridgeTest {
    uint256 public burningLimit;
    uint256 public amount;

    function test_WhenCallerIsNotAGaugeRegisteredInVoter() external {
        // It reverts with NotValidGauge
    }

    modifier whenCallerIsAGaugeRegisteredInVoter() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller(
        uint256 _burningLimit,
        uint256 _amount
    ) external whenCallerIsAGaugeRegisteredInVoter {
        // It should revert with IXERC20_NotHighEnoughLimits
        _burningLimit = bound(_burningLimit, WEEK, type(uint256).max / 2 - 1);
        _amount = bound(_amount, _burningLimit + 1, type(uint256).max / 2);
        deal({token: address(rootXVelo), to: address(rootGauge), give: _amount});

        setLimits({_rootMintingLimit: 0, _leafMintingLimit: _burningLimit});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootBridge), value: _amount});

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        rootBridge.sendToken({_amount: _amount, _chainid: leaf});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(uint256 _burningLimit, uint256 _amount) {
        burningLimit = bound(_burningLimit, WEEK, type(uint256).max / 2);
        amount = bound(_amount, WEEK, burningLimit);
        setLimits({_rootMintingLimit: 0, _leafMintingLimit: burningLimit});
        _;
    }

    function test_WhenTheAmountIsLargerThanTheBalanceOfTheCaller(
        uint256 _burningLimit,
        uint256 _amount,
        uint256 _balance
    )
        external
        whenCallerIsAGaugeRegisteredInVoter
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_burningLimit, _amount)
    {
        // It should revert with ERC20InsufficientBalance
        vm.assume(amount > _balance);
        deal({token: address(rootXVelo), to: address(rootGauge), give: _balance});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(rootGauge), _balance, amount)
        );
        rootBridge.sendToken({_amount: amount, _chainid: leaf});
    }

    function test_WhenTheAmountIsLessThanOrEqualToTheBalanceOfTheCaller(
        uint256 _burningLimit,
        uint256 _amount,
        uint256 _balance
    )
        external
        whenCallerIsAGaugeRegisteredInVoter
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller(_burningLimit, _amount)
    {
        // It burns the caller's tokens
        // It mints the tokens to the caller at the destination
        _balance = bound(_balance, amount, type(uint256).max / 2);
        deal({token: address(rootXVelo), to: address(rootGauge), give: _balance});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootBridge), value: amount});

        vm.expectEmit(address(rootModule));
        emit IHLTokenBridge.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootModule)),
            _value: 0,
            _message: string(abi.encode(address(leafGauge), amount))
        });
        rootBridge.sendToken({_amount: amount, _chainid: leaf});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), _balance - amount);

        vm.selectFork({forkId: leafId});
        vm.expectEmit(address(leafModule));
        emit IHLTokenBridge.ReceivedMessage({
            _origin: root,
            _sender: TypeCasts.addressToBytes32(address(leafModule)),
            _value: 0,
            _message: string(abi.encode(address(leafGauge), amount))
        });
        leafMailbox.processNextInboundMessage();
        assertEq(leafXVelo.balanceOf(address(leafGauge)), amount);
    }
}
