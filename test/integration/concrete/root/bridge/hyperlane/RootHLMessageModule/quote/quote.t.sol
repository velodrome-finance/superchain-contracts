// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootHLMessageModule.t.sol";

contract QuoteIntegrationConcreteTest is RootHLMessageModuleTest {
    function test_WhenTheCallerIsAnyone() external view {
        // It returns the quote
        uint256 fee = rootMessageModule.quote({_destinationDomain: leaf, _messageBody: abi.encode(1)});

        assertEq(fee, MESSAGE_FEE);
    }
}
