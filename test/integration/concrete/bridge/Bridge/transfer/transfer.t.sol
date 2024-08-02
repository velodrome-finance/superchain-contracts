// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract TransferIntegrationConcreteTest is BaseForkFixture {
    uint256 public mintingLimit;
    uint256 public burningLimit;

    function setUp() public override {
        super.setUp();
        mintingLimit = TOKEN_1 * 1000;
        burningLimit = TOKEN_1 * 1000;
    }

    function test_WhenTheCallerIsNotALiveGaugeListedByVoter() external {
        // It should revert with NotValidGauge
        vm.prank(users.charlie);
        originBridge.transfer({_amount: 0, _domain: destination});
    }

    modifier whenTheCallerIsALiveGaugeListedByVoter() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentBurningLimitOfCaller()
        external
        whenTheCallerIsALiveGaugeListedByVoter
    {
        // It should revert with IXERC20_NotHighEnoughLimits
        uint256 amount = 1;
        deal({token: address(originXVelo), to: users.alice, give: amount});

        vm.startPrank(users.alice);
        originXVelo.approve({spender: address(originBridge), value: amount});

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        originBridge.transfer({_amount: amount, _domain: destination});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller() {
        vm.startPrank(users.owner);
        originXVelo.setLimits({_bridge: address(originBridge), _mintingLimit: 0, _burningLimit: burningLimit});
        _;
    }

    function test_WhenTheAmountIsLargerThanTheBalanceOfTheCaller()
        external
        whenTheCallerIsALiveGaugeListedByVoter
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
    {
        // It should revert with ERC20InsufficientBalance
        uint256 amount = TOKEN_1 * 1000;
        deal({token: address(originXVelo), to: users.alice, give: amount - 1});

        vm.startPrank(users.alice);
        originXVelo.approve({spender: address(originBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, users.alice, amount - 1, amount)
        );
        originBridge.transfer({_amount: amount, _domain: destination});
    }

    function test_WhenTheAmountIsLessThanOrEqualToTheBalanceOfTheCaller()
        external
        whenTheCallerIsALiveGaugeListedByVoter
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
    {
        // It burns the amount of tokens from the caller on the origin chain
        // It mints the amount of tokens to the caller on the destination chain
        vm.selectFork({forkId: destinationId});
        vm.startPrank(users.owner);
        destinationXVelo.setLimits({_bridge: address(destinationBridge), _mintingLimit: mintingLimit, _burningLimit: 0});
        vm.selectFork({forkId: originId});

        uint256 amount = TOKEN_1 * 1000;
        deal({token: address(originXVelo), to: users.alice, give: amount});

        vm.startPrank(users.alice);
        originXVelo.approve({spender: address(originBridge), value: amount});

        vm.expectEmit(address(originBridge));
        emit IBridge.SentMessage({
            _destination: destination,
            _recipient: TypeCasts.addressToBytes32(address(originBridge)),
            _value: 0,
            _message: string(abi.encode(users.alice, amount))
        });
        originBridge.transfer({_amount: amount, _domain: destination});

        assertEq(originXVelo.balanceOf(users.alice), 0);
        vm.selectFork({forkId: destinationId});

        vm.expectEmit(address(destinationBridge));
        emit IBridge.ReceivedMessage({
            _origin: origin,
            _sender: TypeCasts.addressToBytes32(address(destinationBridge)),
            _value: 0,
            _message: string(abi.encode(users.alice, amount))
        });
        destinationMailbox.processNextInboundMessage();
        assertEq(destinationXVelo.balanceOf(users.alice), amount);
    }
}
