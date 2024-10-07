// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

/// @notice Commands for x-chain interactions
/// @dev Existing commands cannot be modified but new commands can be added
library Commands {
    // reward deposit & withdraw commands are kept early as these _must_ be sequential
    uint256 public constant DEPOSIT = 0x00;
    uint256 public constant WITHDRAW = 0x01;
    uint256 public constant NOTIFY = 0x02;
    uint256 public constant NOTIFY_WITHOUT_CLAIM = 0x03;
    uint256 public constant GET_INCENTIVES = 0x04;
    uint256 public constant GET_FEES = 0x05;
    uint256 public constant CREATE_GAUGE = 0x06;
    uint256 public constant KILL_GAUGE = 0x07;
    uint256 public constant REVIVE_GAUGE = 0x08;

    uint256 private constant COMMAND_OFFSET = 0;
    uint256 private constant ADDRESS_OFFSET = 1;
    /// @dev Second and Third offset are used in messages with multiple consecutive addresses
    uint256 private constant SECOND_OFFSET = ADDRESS_OFFSET + 20;
    uint256 private constant THIRD_OFFSET = SECOND_OFFSET + 20;
    // Offsets for Create Gauge Command
    uint256 private constant TOKEN0_OFFSET = THIRD_OFFSET + 20;
    uint256 private constant TOKEN1_OFFSET = TOKEN0_OFFSET + 20;
    uint256 private constant POOL_PARAM_OFFSET = TOKEN1_OFFSET + 20;
    // Offsets for Reward Claims
    uint256 private constant LENGTH_OFFSET = THIRD_OFFSET + 32;
    uint256 private constant TOKENS_OFFSET = LENGTH_OFFSET + 1;
    // Offset for Deposit/Withdraw
    uint256 private constant TOKEN_ID_OFFSET = ADDRESS_OFFSET + 20 + 32;
    uint256 private constant NONCE_OFFSET = ADDRESS_OFFSET + 20 + 32 + 32;

    /// @notice Returns the command encoded in the message
    /// @dev Assumes message is encoded as (command, ...)
    /// @param _message The message to be decoded
    function command(bytes calldata _message) internal pure returns (uint256) {
        return uint256(uint8(bytes1(_message[COMMAND_OFFSET:COMMAND_OFFSET + 1])));
    }

    /// @notice Returns the address encoded in the message
    /// @dev Assumes message is encoded as (command, address, ...)
    /// @param _message The message to be decoded
    function toAddress(bytes calldata _message) internal pure returns (address) {
        return address(bytes20(_message[ADDRESS_OFFSET:ADDRESS_OFFSET + 20]));
    }

    /// @notice Returns the message without the encoded command
    /// @dev Assumes message is encoded as (command, message)
    /// @param _message The message to be decoded
    function messageWithoutCommand(bytes calldata _message) internal pure returns (bytes calldata) {
        return bytes(_message[COMMAND_OFFSET + 1:]);
    }

    /// @notice Returns the amount encoded in the message
    /// @dev Assumes message is encoded as (amount, ...)
    /// @param _message The message to be decoded
    function amount(bytes calldata _message) internal pure returns (uint256) {
        return uint256(bytes32(_message[SECOND_OFFSET:SECOND_OFFSET + 32]));
    }

    /// @notice Returns the amount and tokenId encoded in the message
    /// @dev Assumes message is encoded as (amount, tokenId, ...)
    /// @param _message The message to be decoded
    function amountAndTokenId(bytes calldata _message) internal pure returns (uint256, uint256) {
        return (
            uint256(bytes32(_message[SECOND_OFFSET:SECOND_OFFSET + 32])),
            uint256(bytes32(_message[TOKEN_ID_OFFSET:TOKEN_ID_OFFSET + 32]))
        );
    }

    /// @notice Returns the parameters necessary for gauge creation, encoded in the message
    /// @dev Assumes message is encoded as (address, address, address, address, uint24)
    /// @param _message The message to be decoded
    function createGaugeParams(bytes calldata _message)
        internal
        pure
        returns (address, address, address, address, address, uint24)
    {
        return (
            address(bytes20(_message[ADDRESS_OFFSET:ADDRESS_OFFSET + 20])),
            address(bytes20(_message[SECOND_OFFSET:SECOND_OFFSET + 20])),
            address(bytes20(_message[THIRD_OFFSET:THIRD_OFFSET + 20])),
            address(bytes20(_message[TOKEN0_OFFSET:TOKEN0_OFFSET + 20])),
            address(bytes20(_message[TOKEN1_OFFSET:TOKEN1_OFFSET + 20])),
            uint24(bytes3(_message[POOL_PARAM_OFFSET:POOL_PARAM_OFFSET + 3]))
        );
    }

    /// @notice Returns the nonce encoded in the message
    /// @dev Assumes message is encoded as (command, address, ..., nonce)
    /// @param _message The message to be decoded
    function nonce(bytes calldata _message) internal pure returns (uint256) {
        return uint256(bytes32(_message[NONCE_OFFSET:NONCE_OFFSET + 32]));
    }

    /// @notice Returns the owner encoded in the message
    /// @dev Assumes message is encoded as (command, address, owner, ...)
    /// @param _message The message to be decoded
    function owner(bytes calldata _message) internal pure returns (address) {
        return address(bytes20(_message[SECOND_OFFSET:SECOND_OFFSET + 20]));
    }

    /// @notice Returns the tokenId encoded in the message
    /// @dev Assumes message has a tokenId encoded
    /// @param _message The message to be decoded
    function tokenId(bytes calldata _message) internal pure returns (uint256) {
        return uint256(bytes32(_message[THIRD_OFFSET:THIRD_OFFSET + 32]));
    }

    /// @notice Returns the token addresses encoded in the message
    /// @dev Assumes message has length and token addresses encoded
    /// @param _message The message to be decoded
    function tokens(bytes calldata _message) internal pure returns (address[] memory _tokens) {
        uint256 length = uint8(bytes1(_message[LENGTH_OFFSET:LENGTH_OFFSET + 1]));

        _tokens = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _tokens[i] =
                address(uint160(uint256(bytes32(_message[TOKENS_OFFSET + (i * 32):TOKENS_OFFSET + ((i + 1) * 32)]))));
        }
    }
}
