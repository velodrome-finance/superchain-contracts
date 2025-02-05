// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";

import {IPaymasterVault} from "../../../interfaces/root/bridge/hyperlane/IPaymasterVault.sol";
import {IPaymaster} from "../../../interfaces/root/bridge/hyperlane/IPaymaster.sol";

/// @title Velodrome Superchain Paymaster Module
/// @notice Paymaster module used to manage transaction sponsorship & whitelisted addresses
abstract contract Paymaster is IPaymaster {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IPaymaster
    address public paymasterVault;

    /// @dev Set of addresses whitelisted for transaction sponsorship
    EnumerableSet.AddressSet internal _whitelist;

    constructor(address _paymasterVault) {
        paymasterVault = _paymasterVault;
    }

    receive() external payable {
        if (msg.sender != paymasterVault) revert NotPaymasterVault();
    }

    /// @dev Modifier to be overridden for custom access control
    modifier onlyWhitelistManager() virtual;

    /// @inheritdoc IPaymaster
    function whitelistForSponsorship(address _account, bool _state) external onlyWhitelistManager {
        if (_account == address(0)) revert InvalidAddress();
        if (_state) {
            _whitelist.add({value: _account});
        } else {
            _whitelist.remove({value: _account});
        }

        emit WhitelistSet({_account: _account, _state: _state});
    }

    /// @inheritdoc IPaymaster
    function setPaymasterVault(address _paymasterVault) external onlyWhitelistManager {
        if (_paymasterVault == address(0)) revert InvalidAddress();
        paymasterVault = _paymasterVault;
        emit PaymasterVaultSet({_newPaymaster: _paymasterVault});
    }

    /// @dev Helper to pull vault funds for transaction sponsoring
    function _sponsorTransaction(uint256 _fee) internal {
        IPaymasterVault(paymasterVault).sponsorTransaction({_value: _fee});
    }

    /// @inheritdoc IPaymaster
    function whitelist() external view returns (address[] memory) {
        return _whitelist.values();
    }

    /// @inheritdoc IPaymaster
    function whitelistLength() external view returns (uint256) {
        return _whitelist.length();
    }

    /// @inheritdoc IPaymaster
    function isWhitelisted(address _account) external view returns (bool) {
        return _whitelist.contains(_account);
    }
}
