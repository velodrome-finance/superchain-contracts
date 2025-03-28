// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../LeafRestrictedTokenBridge.t.sol";

contract HandleIntegrationConcreteTest is LeafRestrictedTokenBridgeTest {
    using SafeCast for uint256;

    bytes32 _sender = TypeCasts.addressToBytes32(users.charlie);
    uint256 _amount = TOKEN_1 * 1000;
    uint256 _bufferCap = TOKEN_1 * 2000;

    function test_WhenTheCallerIsNotMailbox() external {
        // It should revert with {NotMailbox}
        vm.prank(users.charlie);
        vm.expectRevert(IHLHandler.NotMailbox.selector);
        leafRestrictedTokenBridge.handle({
            _origin: rootDomain,
            _sender: _sender,
            _message: abi.encodePacked(users.charlie, _amount)
        });
    }

    modifier whenTheCallerIsMailbox() {
        _;
    }

    function test_WhenTheSenderIsNotBridge() external whenTheCallerIsMailbox {
        // It should revert with {NotBridge}
        vm.prank(address(leafMailbox));
        vm.expectRevert(ITokenBridge.NotBridge.selector);
        leafRestrictedTokenBridge.handle({
            _origin: rootDomain,
            _sender: _sender,
            _message: abi.encodePacked(users.charlie, _amount)
        });
    }

    modifier whenTheSenderIsBridge() {
        _sender = TypeCasts.addressToBytes32(address(leafRestrictedTokenBridge));
        _;
    }

    function test_WhenTheOriginChainIsNotARegisteredChain() external whenTheCallerIsMailbox whenTheSenderIsBridge {
        // It should revert with {NotRegistered}
        vm.prank(address(leafMailbox));
        vm.expectRevert(IChainRegistry.NotRegistered.selector);
        leafRestrictedTokenBridge.handle({
            _origin: rootDomain,
            _sender: _sender,
            _message: abi.encodePacked(users.charlie, _amount)
        });
    }

    modifier whenTheOriginChainIsARegisteredChain() {
        vm.prank(users.owner);
        leafRestrictedTokenBridge.registerChain({_chainid: rootDomain});
        _;
    }

    function test_WhenTheRecipientHasAnIncentiveRewardContract()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginChainIsARegisteredChain
    {
        // It should mint tokens to the bridge
        // It should approve the incentive reward contract
        // It should notify the reward amount
        // It should emit {ReceivedMessage} event
        vm.prank(users.owner);
        leafRestrictedRewardToken.addBridge({
            _newBridge: MintLimits.RateLimitMidPointInfo({
                bridge: address(leafRestrictedTokenBridge),
                bufferCap: _bufferCap.toUint112(),
                rateLimitPerSecond: (_bufferCap / DAY).toUint128()
            })
        });

        vm.deal(address(leafMailbox), _amount / 2);
        bytes memory _message = abi.encodePacked(address(leafGauge), _amount);

        address _token = address(leafRestrictedRewardToken);
        uint256 _epochStart = VelodromeTimeLibrary.epochStart(block.timestamp);
        uint256 _tokenRewardsPerEpoch = leafIVR.tokenRewardsPerEpoch(_token, _epochStart);
        uint256 _rewardsLength = leafIVR.rewardsListLength();

        vm.prank(address(leafMailbox));
        vm.expectEmit(address(leafRestrictedTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: _sender,
            _value: _amount / 2,
            _message: string(_message)
        });
        leafRestrictedTokenBridge.handle{value: _amount / 2}({_origin: rootDomain, _sender: _sender, _message: _message});

        assertEq(leafRestrictedRewardToken.balanceOf(address(leafRestrictedTokenBridge)), 0);
        assertEq(leafRestrictedRewardToken.balanceOf(address(leafIVR)), _amount);

        // Verify reward token state updates
        assertTrue(leafIVR.isReward(_token));
        assertEq(leafIVR.rewardsListLength(), _rewardsLength + 1);
        assertEq(leafIVR.rewards(_rewardsLength), _token);

        // Verify rewards per epoch was updated
        assertEq(leafIVR.tokenRewardsPerEpoch(_token, _epochStart), _tokenRewardsPerEpoch + _amount);

        // Verify IVR was added to whitelist
        address[] memory _whitelist = leafRestrictedRewardToken.whitelist();
        assertEq(_whitelist.length, 2);
        assertEq(_whitelist[0], address(leafRestrictedTokenBridge));
        assertEq(_whitelist[1], address(leafIVR));
    }

    function test_WhenTheRecipientDoesNotHaveAnIncentiveRewardContract()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginChainIsARegisteredChain
    {
        // It should mint tokens directly to the recipient
        // It should emit {ReceivedMessage} event
        vm.prank(users.owner);
        leafRestrictedRewardToken.addBridge({
            _newBridge: MintLimits.RateLimitMidPointInfo({
                bridge: address(leafRestrictedTokenBridge),
                bufferCap: _bufferCap.toUint112(),
                rateLimitPerSecond: (_bufferCap / DAY).toUint128()
            })
        });

        vm.deal(address(leafMailbox), _amount / 2);
        bytes memory _message = abi.encodePacked(users.bob, _amount);

        vm.prank(address(leafMailbox));
        vm.expectEmit(address(leafRestrictedTokenBridge));
        emit IHLHandler.ReceivedMessage({
            _origin: rootDomain,
            _sender: _sender,
            _value: _amount / 2,
            _message: string(_message)
        });
        leafRestrictedTokenBridge.handle{value: _amount / 2}({_origin: rootDomain, _sender: _sender, _message: _message});

        assertEq(leafRestrictedRewardToken.balanceOf(users.bob), _amount);

        // verify restricted xerc20 whitelist unchanged
        address[] memory _whitelist = leafRestrictedRewardToken.whitelist();
        assertEq(_whitelist.length, 1);
        assertEq(_whitelist[0], address(leafRestrictedTokenBridge));
    }

    function testGas_handle()
        external
        whenTheCallerIsMailbox
        whenTheSenderIsBridge
        whenTheOriginChainIsARegisteredChain
    {
        vm.prank(users.owner);
        leafRestrictedRewardToken.addBridge({
            _newBridge: MintLimits.RateLimitMidPointInfo({
                bridge: address(leafRestrictedTokenBridge),
                bufferCap: _bufferCap.toUint112(),
                rateLimitPerSecond: (_bufferCap / DAY).toUint128()
            })
        });

        vm.deal(address(leafMailbox), _amount);
        bytes memory _message = abi.encodePacked(address(leafGauge), _amount);

        vm.prank(address(leafMailbox));
        leafRestrictedTokenBridge.handle{value: _amount / 2}({_origin: rootDomain, _sender: _sender, _message: _message});
        vm.snapshotGasLastCall("LeafRestrictedTokenBridge_handle");
    }
}
