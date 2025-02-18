// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract QuoteIntegrationFuzzTest is RootHLMessageModuleTest {
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

    function testFuzz_WhenTheCurrentTimestampIsInTheDistributeWindow(uint256 _timestamp)
        external
        whenTheCommandIsNotify
    {
        // It returns 0
        _timestamp = bound(
            _timestamp,
            VelodromeTimeLibrary.epochStart(block.timestamp),
            VelodromeTimeLibrary.epochVoteStart(block.timestamp)
        );
        vm.warp({newTimestamp: _timestamp});
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), TOKEN_1);

        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, 0);
    }

    modifier whenTheCurrentTimestampIsNotInTheDistributeWindow(uint256 _timestamp) {
        leafStartTime = bound(
            _timestamp,
            VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1,
            VelodromeTimeLibrary.epochNext(block.timestamp) - 1
        );
        vm.warp({newTimestamp: leafStartTime});
        _;
    }

    function testFuzz_WhenThereIsNoDomainSetForTheChain(uint256 _timestamp)
        external
        whenTheCommandIsNotify
        whenTheCurrentTimestampIsNotInTheDistributeWindow(_timestamp)
    {
        // It returns the quote for the chainid
        _deregisterLeafDomain();
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), TOKEN_1);

        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE_CHAIN_ID);
    }

    function testFuzz_WhenThereIsADomainSetForTheChain(uint256 _timestamp)
        external
        whenTheCommandIsNotify
        whenTheCurrentTimestampIsNotInTheDistributeWindow(_timestamp)
    {
        // It returns the quote for the custom domain
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), TOKEN_1);

        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }

    modifier whenTheCommandIsNotNotify() {
        _;
    }

    function testFuzz_WhenTheCallerIsWhitelisted(address _sender) external whenTheCommandIsNotNotify {
        // It returns 0
        vm.assume(_sender != address(0));
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), TOKEN_1, uint256(1), block.timestamp);

        vm.prank(rootMessageBridge.owner());
        rootMessageModule.whitelistForSponsorship({_account: _sender, _state: true});

        vm.prank({msgSender: _sender, txOrigin: _sender});
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, 0);
    }

    modifier whenTheCallerIsNotWhitelisted(address _sender) {
        vm.assume(_sender != address(0));
        _;
    }

    function testFuzz_WhenThereIsNoDomainSetForTheChain_(address _sender)
        external
        whenTheCommandIsNotNotify
        whenTheCallerIsNotWhitelisted(_sender)
    {
        // It returns the quote for the chainid
        _deregisterLeafDomain();
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), TOKEN_1, uint256(1), block.timestamp);

        vm.prank({msgSender: _sender, txOrigin: _sender});
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE_CHAIN_ID);
    }

    function testFuzz_WhenThereIsADomainSetForTheChain_(address _sender)
        external
        whenTheCommandIsNotNotify
        whenTheCallerIsNotWhitelisted(_sender)
    {
        // It returns the quote for the custom domain
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), TOKEN_1, uint256(1), block.timestamp);

        vm.prank({msgSender: _sender, txOrigin: _sender});
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }
}
