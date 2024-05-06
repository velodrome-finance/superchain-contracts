// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ITokenRegistry} from "../../interfaces/gauges/tokenregistry/ITokenRegistry.sol";

/// @title Velodrome xChain Token Registry Contract
/// @author velodrome.finance
/// @notice Registry contract designed to keep track of Whitelisted tokens
contract TokenRegistry is ITokenRegistry {
    /// @inheritdoc ITokenRegistry
    address public admin;

    /// @inheritdoc ITokenRegistry
    mapping(address => bool) public isWhitelistedToken;

    constructor(address _admin, address[] memory _whitelistedTokens) {
        uint256 length = _whitelistedTokens.length;
        for (uint256 i = 0; i < length; i++) {
            _whitelistToken({_token: _whitelistedTokens[i], _state: true});
        }
        admin = _admin;
        emit SetAdmin({admin: _admin});
    }

    /// @inheritdoc ITokenRegistry
    function whitelistToken(address _token, bool _state) external {
        if (msg.sender != admin) revert NotAdmin();
        if (_token == address(0)) revert ZeroAddress();
        _whitelistToken(_token, _state);
    }

    function _whitelistToken(address _token, bool _state) internal {
        isWhitelistedToken[_token] = _state;
        emit WhitelistToken({whitelister: msg.sender, token: _token, state: _state});
    }

    /// @inheritdoc ITokenRegistry
    function setAdmin(address _admin) public {
        if (msg.sender != admin) revert NotAdmin();
        if (_admin == address(0)) revert ZeroAddress();
        admin = _admin;
        emit SetAdmin({admin: _admin});
    }
}
