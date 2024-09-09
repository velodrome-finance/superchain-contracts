// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootMessageBridge.t.sol";

contract RegisterChainIntegrationConcreteTest is RootMessageBridgeTest {
    function setUp() public override {
        super.setUp();

        // deploy fresh instance
        rootMessageBridge = RootMessageBridge(
            cx.deployCreate3({
                salt: CreateXLibrary.calculateSalt({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer}),
                initCode: abi.encodePacked(
                    type(RootMessageBridge).creationCode,
                    abi.encode(
                        users.owner, // message bridge owner
                        address(rootXVelo), // xerc20 address
                        address(mockVoter), // mock root voter
                        address(rootMessageModule), // message module
                        address(rootGaugeFactory) // root gauge factory
                    )
                )
            })
        );
    }

    function test_WhenTheCallerIsNotTheOwner() external {
        // It reverts with {OwnableUnauthorizedAccount}
        vm.prank(users.charlie);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.charlie));
        rootMessageBridge.registerChain({_chainid: 10});
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(users.owner);
        _;
    }

    function test_WhenTheChainIsTheCurrentChain() external whenTheCallerIsTheOwner {
        // It reverts with {InvalidChain}
        uint256 chainid = block.chainid;

        vm.expectRevert(IChainRegistry.InvalidChain.selector);
        rootMessageBridge.registerChain({_chainid: chainid});
    }

    modifier whenTheChainIsNotTheCurrentChain() {
        _;
    }

    function test_WhenTheChainIsAlreadyRegistered() external whenTheCallerIsTheOwner whenTheChainIsNotTheCurrentChain {
        // It reverts with {AlreadyRegistered}
        uint256 chainid = 100;
        rootMessageBridge.registerChain({_chainid: chainid});

        vm.expectRevert(IChainRegistry.AlreadyRegistered.selector);
        rootMessageBridge.registerChain({_chainid: chainid});
    }

    function test_WhenTheChainIsNotAlreadyRegistered()
        external
        whenTheCallerIsTheOwner
        whenTheChainIsNotTheCurrentChain
    {
        // It registers the chain id
        // It emits the {ChainRegistered} event
        uint256 chainid = 100;

        vm.expectEmit(address(rootMessageBridge));
        emit IChainRegistry.ChainRegistered({_chainid: chainid});
        rootMessageBridge.registerChain({_chainid: chainid});

        uint256[] memory chainids = rootMessageBridge.chainids();
        assertEq(chainids.length, 1);
        assertEq(chainids[0], chainid);
    }
}
