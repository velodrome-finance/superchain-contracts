// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract QuoteIntegrationConcreteTest is RootHLMessageModuleTest {
    /// @dev Custom message fee applied when no domain is set
    uint256 public constant MESSAGE_FEE_CHAIN_ID = MESSAGE_FEE / 2;

    function setUp() public override {
        super.setUp();

        /// @dev partially mock `quoteDispatch` to use different quote when chainid is equal to domain
        vm.mockCall({
            callee: address(rootMailbox),
            data: abi.encodeWithSelector(bytes4(keccak256("quoteDispatch(uint32,bytes32,bytes,bytes,address)")), leaf),
            returnData: abi.encode(MESSAGE_FEE_CHAIN_ID)
        });
    }

    /// @dev Helper function to deregister Leaf Chain's domain
    function _deregisterLeafDomain() internal {
        vm.startPrank(rootMessageBridge.owner());
        rootMessageModule.setDomain({_chainid: leaf, _domain: 0});
        // @dev if domain not linked to chain, domain should be equal to chainid
        leafDomain = leaf;

        assertEq(rootMessageModule.domains(leaf), 0);

        rootMailbox.addRemoteMailbox({_domain: leaf, _mailbox: leafMailbox});
        rootMailbox.setDomainForkId({_domain: leaf, _forkId: leafId});

        vm.selectFork({forkId: leafId});
        vm.warp({newTimestamp: leafStartTime});

        // Deploy mock mailbox with leaf chainid as domain
        vm.startPrank(users.deployer);
        MultichainMockMailbox leafMailboxDefaultChainid = new MultichainMockMailbox(leaf);
        vm.stopPrank();

        // Mock `mailbox.process()` to process messages using leaf chainid as domain
        vm.mockFunction(
            address(leafMailbox), address(leafMailboxDefaultChainid), abi.encodeWithSelector(Mailbox.process.selector)
        );

        vm.selectFork({forkId: rootId});
        vm.warp({newTimestamp: leafStartTime});
    }

    modifier whenTheCommandIsNotify() {
        _;
    }

    function test_WhenTheCurrentTimestampIsInTheDistributeWindow() external whenTheCommandIsNotify {
        // It returns 0
        uint256 timestamp = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: timestamp});
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), TOKEN_1);

        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, 0);
    }

    modifier whenTheCurrentTimestampIsNotInTheDistributeWindow() {
        leafStartTime = VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1;
        vm.warp({newTimestamp: leafStartTime});
        _;
    }

    function test_WhenThereIsNoDomainSetForTheChain()
        external
        whenTheCommandIsNotify
        whenTheCurrentTimestampIsNotInTheDistributeWindow
    {
        // It returns the quote for the chainid
        _deregisterLeafDomain();
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), TOKEN_1);

        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE_CHAIN_ID);
    }

    function test_WhenThereIsADomainSetForTheChain()
        external
        whenTheCommandIsNotify
        whenTheCurrentTimestampIsNotInTheDistributeWindow
    {
        // It returns the quote for the custom domain
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), TOKEN_1);

        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }

    modifier whenTheCommandIsNotNotify() {
        _;
    }

    function test_WhenTheCallerIsWhitelisted() external whenTheCommandIsNotNotify {
        // It returns 0
        address sender = users.alice;
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), TOKEN_1, uint256(1), block.timestamp);

        vm.prank(rootMessageBridge.owner());
        rootMessageModule.whitelistForSponsorship({_account: sender, _state: true});

        vm.prank({msgSender: sender, txOrigin: sender});
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, 0);
    }

    modifier whenTheCallerIsNotWhitelisted() {
        _;
    }

    function test_WhenThereIsNoDomainSetForTheChain_()
        external
        whenTheCommandIsNotNotify
        whenTheCallerIsNotWhitelisted
    {
        // It returns the quote for the chainid
        _deregisterLeafDomain();
        address sender = users.alice;
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), TOKEN_1, uint256(1), block.timestamp);

        vm.prank({msgSender: sender, txOrigin: sender});
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE_CHAIN_ID);
    }

    function test_WhenThereIsADomainSetForTheChain_()
        external
        whenTheCommandIsNotNotify
        whenTheCallerIsNotWhitelisted
    {
        // It returns the quote for the custom domain
        address sender = users.alice;
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), TOKEN_1, uint256(1), block.timestamp);

        vm.prank({msgSender: sender, txOrigin: sender});
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }
}
