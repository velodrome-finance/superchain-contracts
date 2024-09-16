// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {Message} from "@hyperlane/core/contracts/libs/Message.sol";
import {IMessageRecipient} from "@hyperlane/core/contracts/interfaces/IMessageRecipient.sol";
import {Mailbox} from "@hyperlane/core/contracts/Mailbox.sol";
import {IPostDispatchHook} from "@hyperlane/core/contracts/interfaces/hooks/IPostDispatchHook.sol";

import {TestIsm} from "@hyperlane/core/contracts/test/TestIsm.sol";
import {TestPostDispatchHook} from "@hyperlane/core/contracts/test/TestPostDispatchHook.sol";

import {Test} from "forge-std/Test.sol";

contract MultichainMockMailbox is Mailbox, Test {
    using Message for bytes;

    uint32 public inboundUnprocessedNonce = 0;
    uint32 public inboundProcessedNonce = 0;

    mapping(uint32 => MultichainMockMailbox) public remoteMailboxes;
    mapping(uint256 => bytes) public inboundMessages;
    mapping(uint32 => uint256) public forkId;

    constructor(uint32 _domain) Mailbox(_domain) {
        TestIsm ism = new TestIsm();
        defaultIsm = ism;

        TestPostDispatchHook hook = new TestPostDispatchHook();
        defaultHook = hook;
        requiredHook = hook;

        _transferOwnership(msg.sender);
        _disableInitializers();
    }

    function setDomainForkId(uint32 _domain, uint256 _forkId) external {
        forkId[_domain] = _forkId;
    }

    function addRemoteMailbox(uint32 _domain, MultichainMockMailbox _mailbox) external {
        remoteMailboxes[_domain] = _mailbox;
    }

    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody,
        bytes calldata metadata,
        IPostDispatchHook hook
    ) public payable override returns (bytes32) {
        bytes memory message = _buildMessage(destinationDomain, recipientAddress, messageBody);
        bytes32 id = super.dispatch(destinationDomain, recipientAddress, messageBody, metadata, hook);

        MultichainMockMailbox _destinationMailbox = remoteMailboxes[destinationDomain];
        require(address(_destinationMailbox) != address(0), "Missing remote mailbox");
        uint256 activeFork = vm.activeFork();
        // Add inbound message on the destination chain
        vm.selectFork({forkId: forkId[destinationDomain]});
        _destinationMailbox.addInboundMessage(message);
        vm.selectFork({forkId: activeFork});

        return id;
    }

    function addInboundMessage(bytes calldata message) external {
        inboundMessages[inboundUnprocessedNonce] = message;
        inboundUnprocessedNonce++;
    }

    function processNextInboundMessage() public {
        bytes memory _message = inboundMessages[inboundProcessedNonce];
        Mailbox(address(this)).process("", _message);
        inboundProcessedNonce++;
    }
}
