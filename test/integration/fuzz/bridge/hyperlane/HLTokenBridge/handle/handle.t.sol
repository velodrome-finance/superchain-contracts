// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../HLTokenBridge.t.sol";

contract HandleIntegrationFuzzTest is HLTokenBridgeTest {
    function setUp() public override {
        super.setUp();
        vm.selectFork({forkId: leafId});
    }

    function test_WhenTheCallerIsNotMailbox(address _caller) external {
        // It should revert with NotMailbox
        vm.assume(_caller != address(leafMailbox));

        vm.prank(_caller);
        vm.expectRevert(IHLTokenBridge.NotMailbox.selector);
        leafModule.handle({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(_caller),
            _message: abi.encode(_caller, 1)
        });
    }

    modifier whenTheCallerIsMailbox() {
        _;
    }

    function test_WhenTheRequestedAmountIsHigherThanTheCurrentMintingLimit(uint256 _mintingLimit, uint256 _amount)
        external
        whenTheCallerIsMailbox
    {
        // It should revert with IXERC20_NotHighEnoughLimits
        _mintingLimit = bound(_mintingLimit, WEEK, type(uint256).max / 2);
        vm.assume(_amount > _mintingLimit);

        vm.deal(address(leafMailbox), TOKEN_1);

        bytes memory _message = abi.encode(address(leafGauge), _amount);

        vm.prank(address(leafMailbox));
        vm.expectRevert(IXERC20.IXERC20_NotHighEnoughLimits.selector);
        leafModule.handle{value: TOKEN_1 / 2}({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _message: _message
        });
    }

    function test_WhenTheRequestedAmountIsLessThanOrEqualToTheCurrentMintingLimit(
        uint256 _mintingLimit,
        uint256 _amount
    ) external whenTheCallerIsMailbox {
        // It should mint tokens to the destination module
        // It should deposit the tokens into the gauge
        _mintingLimit = bound(_mintingLimit, WEEK, type(uint256).max / 2);
        _amount = bound(_amount, WEEK, _mintingLimit);

        vm.prank(users.owner);
        leafXVelo.setLimits({_bridge: address(leafBridge), _mintingLimit: _mintingLimit, _burningLimit: 0});

        vm.deal(address(leafMailbox), TOKEN_1 / 2);

        bytes memory _message = abi.encode(address(leafGauge), _amount);

        vm.prank(address(leafMailbox));
        vm.expectEmit(address(leafModule));
        emit IHLTokenBridge.ReceivedMessage({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _value: TOKEN_1 / 2,
            _message: string(_message)
        });
        leafModule.handle{value: TOKEN_1 / 2}({
            _origin: leaf,
            _sender: TypeCasts.addressToBytes32(users.alice),
            _message: _message
        });

        assertEq(leafXVelo.balanceOf(address(leafGauge)), _amount);
    }
}
