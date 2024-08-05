// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract TransferIntegrationConcreteTest is BaseForkFixture {
    address public rootPool;
    RootGauge public rootGauge;
    address public leafPool;
    LeafGauge public leafGauge;

    function setUp() public override {
        super.setUp();

        vm.selectFork({forkId: originId});
        rootPool = originRootPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: false});
        rootGauge =
            RootGauge(mockVoter.createGauge({_poolFactory: address(originRootPoolFactory), _pool: address(rootPool)}));

        vm.selectFork({forkId: destinationId});
        leafPool = destinationPoolFactory.createPool({tokenA: address(token0), tokenB: address(token1), stable: false});
        leafGauge = LeafGauge(
            destinationLeafGaugeFactory.createGauge({
                _token0: address(token0),
                _token1: address(token1),
                _stable: false,
                _feesVotingReward: address(11),
                isPool: true
            })
        );

        vm.selectFork({forkId: originId});
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
        deal({token: address(originXVelo), to: address(rootGauge), give: amount});

        vm.startPrank(address(rootGauge));
        originXVelo.approve({spender: address(originBridge), value: amount});

        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        originBridge.transfer({_amount: amount, _domain: destination});
    }

    modifier whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller() {
        uint256 amount = TOKEN_1 * 1_000;
        setLimits({_originMintingLimit: amount, _destinationMintingLimit: amount});
        _;
    }

    function test_WhenTheAmountIsLargerThanTheBalanceOfTheCaller()
        external
        whenTheCallerIsALiveGaugeListedByVoter
        whenTheAmountIsLessThanOrEqualToTheCurrentBurningLimitOfCaller
    {
        // It should revert with ERC20InsufficientBalance
        uint256 amount = TOKEN_1 * 1000;
        deal({token: address(originXVelo), to: address(rootGauge), give: amount - 1});

        vm.startPrank(address(rootGauge));
        originXVelo.approve({spender: address(originBridge), value: amount});

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(rootGauge), amount - 1, amount
            )
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
        uint256 amount = TOKEN_1 * 1000;
        deal({token: address(originXVelo), to: address(rootGauge), give: amount});

        vm.startPrank(address(rootGauge));
        originXVelo.approve({spender: address(originBridge), value: amount});

        vm.expectEmit(address(originBridge));
        emit IBridge.SentMessage({
            _destination: destination,
            _recipient: TypeCasts.addressToBytes32(address(originBridge)),
            _value: 0,
            _message: string(abi.encode(address(leafGauge), amount))
        });
        originBridge.transfer({_amount: amount, _domain: destination});

        assertEq(originXVelo.balanceOf(address(rootGauge)), 0);

        vm.selectFork({forkId: destinationId});
        vm.expectEmit(address(destinationBridge));
        emit IBridge.ReceivedMessage({
            _origin: origin,
            _sender: TypeCasts.addressToBytes32(address(destinationBridge)),
            _value: 0,
            _message: string(abi.encode(address(leafGauge), amount))
        });
        destinationMailbox.processNextInboundMessage();
        assertEq(destinationXVelo.balanceOf(address(leafGauge)), amount);
    }
}
