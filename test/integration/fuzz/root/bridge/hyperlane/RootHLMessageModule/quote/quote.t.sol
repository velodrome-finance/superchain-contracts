// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract QuoteIntegrationFuzzTest is RootHLMessageModuleTest {
    modifier whenTheCommandIsANotifyCommand() {
        _;
    }

    function testFuzz_WhenTheCurrentTimestampIsInTheDistributeWindow(uint256 _timestamp)
        external
        whenTheCommandIsANotifyCommand
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

    function testFuzz_WhenTheCurrentTimestampIsNotInTheDistributeWindow(uint256 _timestamp)
        external
        whenTheCommandIsANotifyCommand
    {
        // It returns the quote
        _timestamp = bound(
            _timestamp,
            VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1,
            VelodromeTimeLibrary.epochNext(block.timestamp) - 1
        );
        vm.warp({newTimestamp: _timestamp});
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), TOKEN_1);

        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }

    modifier whenTheCommandIsNotANotifyCommand() {
        _;
    }

    modifier whenTheCommandIsAnNftCommand() {
        _;
    }

    function testFuzz_WhenTheCallerIsWhitelisted(address _sender)
        external
        whenTheCommandIsNotANotifyCommand
        whenTheCommandIsAnNftCommand
    {
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

    function testFuzz_WhenTheCallerIsNotWhitelisted(address _sender)
        external
        whenTheCommandIsNotANotifyCommand
        whenTheCommandIsAnNftCommand
    {
        // It returns the quote
        vm.assume(_sender != address(0));
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), TOKEN_1, uint256(1), block.timestamp);

        vm.prank({msgSender: _sender, txOrigin: _sender});
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }

    function testFuzz_WhenTheCommandIsNotAnNftCommand() external view whenTheCommandIsNotANotifyCommand {
        // It returns the quote
        bytes memory message = abi.encodePacked(uint8(Commands.KILL_GAUGE), address(leafGauge));

        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }
}
