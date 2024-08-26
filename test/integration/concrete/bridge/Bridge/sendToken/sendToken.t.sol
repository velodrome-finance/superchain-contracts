// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../Bridge.t.sol";

contract SendTokenIntegrationConcreteTest is BridgeTest {
    function test_WhenCallerIsNotAGaugeRegisteredInVoter() external {
        // It reverts with NotValidGauge
        mockVoter.killGauge(address(leafGauge));

        uint256 amount = 1;
        vm.expectRevert(IBridge.NotValidGauge.selector);
        rootBridge.sendToken({_amount: amount, _chainid: leaf});
    }

    modifier whenCallerIsAGaugeRegisteredInVoter() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller()
        external
        whenCallerIsAGaugeRegisteredInVoter
    {
        // It should revert with IXERC20_NotHighEnoughLimits
        uint256 amount = 1;
        deal({token: address(rootXVelo), to: address(rootGauge), give: amount});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootBridge), value: amount});

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        rootBridge.sendToken({_amount: amount, _chainid: leaf});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller() {
        uint256 amount = TOKEN_1 * 1_000;
        setLimits({_rootMintingLimit: amount, _leafMintingLimit: amount});
        _;
    }

    function test_WhenTheAmountIsLargerThanTheBalanceOfTheCaller()
        external
        whenCallerIsAGaugeRegisteredInVoter
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
    {
        // It should revert with ERC20InsufficientBalance
        uint256 amount = TOKEN_1 * 1000;
        deal({token: address(rootXVelo), to: address(rootGauge), give: amount - 1});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(rootGauge), amount - 1, amount
            )
        );
        rootBridge.sendToken({_amount: amount, _chainid: leaf});
    }

    function test_WhenTheAmountIsLessThanOrEqualToTheBalanceOfTheCaller()
        external
        whenCallerIsAGaugeRegisteredInVoter
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
    {
        // It burns the caller's tokens
        // It mints the tokens to the caller at the destination
        uint256 amount = TOKEN_1 * 1000;
        uint256 ethAmount = TOKEN_1;
        setLimits({_rootMintingLimit: amount, _leafMintingLimit: amount});
        deal({token: address(rootXVelo), to: address(rootGauge), give: amount});
        vm.deal({account: address(rootGauge), newBalance: ethAmount});

        vm.startPrank(address(rootGauge));
        rootXVelo.approve({spender: address(rootBridge), value: amount});

        vm.expectEmit(address(rootModule));
        emit IHLTokenBridge.SentMessage({
            _destination: leaf,
            _recipient: TypeCasts.addressToBytes32(address(rootModule)),
            _value: ethAmount,
            _message: string(abi.encode(address(leafGauge), amount))
        });
        rootBridge.sendToken{value: ethAmount}({_amount: amount, _chainid: leaf});

        assertEq(rootXVelo.balanceOf(address(rootGauge)), 0);
        assertEq(address(rootBridge).balance, 0);

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
