// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";

abstract contract RootMessageBridgeTest is BaseForkFixture {
    RootMessageBridge newRootMessageBridge;

    function setUp() public virtual override {
        super.setUp();

        // deploy fresh instance
        newRootMessageBridge = RootMessageBridge(
            payable(
                cx.deployCreate3({
                    salt: CreateXLibrary.calculateSalt({_entropy: MESSAGE_BRIDGE_ENTROPY, _deployer: users.deployer}),
                    initCode: abi.encodePacked(
                        type(RootMessageBridge).creationCode,
                        abi.encode(
                            users.owner, // message bridge owner
                            address(rootXVelo), // xerc20 address
                            address(mockVoter), // mock root voter
                            address(rootMessageModule), // message module
                            address(rootGaugeFactory), // root gauge factory
                            address(weth) // root weth
                        )
                    )
                })
            )
        );
    }

    function test_InitialState() public {
        vm.selectFork({forkId: rootId});
        assertEq(rootMessageBridge.owner(), users.owner);
        assertEq(rootMessageBridge.xerc20(), address(rootXVelo));
        assertEq(rootMessageBridge.voter(), address(mockVoter));
        assertEq(rootMessageBridge.factoryRegistry(), address(mockFactoryRegistry));
        assertEq(rootMessageBridge.module(), address(rootMessageModule));
        assertEq(rootMessageBridge.weth(), address(weth));
    }
}
