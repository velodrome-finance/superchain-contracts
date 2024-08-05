// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

contract HandleIntegrationConcreteTest is BaseForkFixture {
    address public leafPool;
    LeafGauge public leafGauge;

    function setUp() public override {
        super.setUp();

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
    }

    function test_WhenTheCallerIsNotMailbox() external {
        // It should revert with NotMailbox
        vm.prank(users.charlie);
        vm.expectRevert(IBridge.NotMailbox.selector);
        destinationBridge.handle({
            _origin: destination,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _message: abi.encode(users.alice, 1)
        });
    }

    modifier whenTheCallerIsMailbox() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit() external whenTheCallerIsMailbox {
        // It should revert with IXERC20_NotHighEnoughLimits
        uint256 amount = TOKEN_1;

        vm.deal(address(destinationMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), amount);

        vm.prank(address(destinationMailbox));
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        destinationBridge.handle{value: TOKEN_1 / 2}({
            _origin: destination,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _message: _message
        });
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit() external whenTheCallerIsMailbox {
        // It should mint tokens to the destination contract
        uint256 amount = TOKEN_1;

        vm.prank(users.owner);
        destinationXVelo.setLimits({_bridge: address(destinationBridge), _mintingLimit: amount, _burningLimit: 0});

        vm.deal(address(destinationMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), amount);

        vm.prank(address(destinationMailbox));
        vm.expectEmit(address(destinationBridge));
        emit IBridge.ReceivedMessage({
            _origin: destination,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        destinationBridge.handle{value: TOKEN_1 / 2}({
            _origin: destination,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _message: _message
        });

        assertEq(originXVelo.balanceOf(address(leafGauge)), amount);
    }
}
