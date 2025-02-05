// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract QuoteIntegrationConcreteTest is RootHLMessageModuleTest {
    modifier whenTheCommandIsANotifyCommand() {
        _;
    }

    function test_WhenTheCurrentTimestampIsInTheDistributeWindow() external whenTheCommandIsANotifyCommand {
        // It returns 0
        uint256 timestamp = VelodromeTimeLibrary.epochStart(block.timestamp);
        vm.warp({newTimestamp: timestamp});
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), TOKEN_1);

        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, 0);
    }

    function test_WhenTheCurrentTimestampIsNotInTheDistributeWindow() external whenTheCommandIsANotifyCommand {
        // It returns the quote
        uint256 timestamp = VelodromeTimeLibrary.epochVoteStart(block.timestamp) + 1;
        vm.warp({newTimestamp: timestamp});
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

    function test_WhenTheCallerIsWhitelisted()
        external
        whenTheCommandIsNotANotifyCommand
        whenTheCommandIsAnNftCommand
    {
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

    function test_WhenTheCallerIsNotWhitelisted()
        external
        whenTheCommandIsNotANotifyCommand
        whenTheCommandIsAnNftCommand
    {
        // It returns the quote
        address sender = users.charlie;
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), TOKEN_1, uint256(1), block.timestamp);

        vm.prank({msgSender: sender, txOrigin: sender});
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }

    function test_WhenTheCommandIsNotAnNftCommand() external view whenTheCommandIsNotANotifyCommand {
        // It returns the quote
        bytes memory message = abi.encodePacked(uint8(Commands.KILL_GAUGE), address(leafGauge));

        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: message});
        assertEq(fee, MESSAGE_FEE);
    }
}
