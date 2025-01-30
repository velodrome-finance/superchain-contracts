// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";

import {XERC20} from "../XERC20.sol";
import {CreateXLibrary} from "../../libraries/CreateXLibrary.sol";
import {IRestrictedXERC20} from "../../interfaces/xerc20/extensions/IRestrictedXERC20.sol";

/*

██╗   ██╗███████╗██╗      ██████╗ ██████╗ ██████╗  ██████╗ ███╗   ███╗███████╗
██║   ██║██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗██╔═══██╗████╗ ████║██╔════╝
██║   ██║█████╗  ██║     ██║   ██║██║  ██║██████╔╝██║   ██║██╔████╔██║█████╗
╚██╗ ██╔╝██╔══╝  ██║     ██║   ██║██║  ██║██╔══██╗██║   ██║██║╚██╔╝██║██╔══╝
 ╚████╔╝ ███████╗███████╗╚██████╔╝██████╔╝██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗
  ╚═══╝  ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝

███████╗██╗   ██╗██████╗ ███████╗██████╗  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║██╔══██╗██║████╗  ██║
███████╗██║   ██║██████╔╝█████╗  ██████╔╝██║     ███████║███████║██║██╔██╗ ██║
╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██║     ██╔══██║██╔══██║██║██║╚██╗██║
███████║╚██████╔╝██║     ███████╗██║  ██║╚██████╗██║  ██║██║  ██║██║██║ ╚████║
╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝

██████╗ ███████╗███████╗████████╗██████╗ ██╗ ██████╗████████╗███████╗██████╗ 
██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██║██╔════╝╚══██╔══╝██╔════╝██╔══██╗
██████╔╝█████╗  ███████╗   ██║   ██████╔╝██║██║        ██║   █████╗  ██║  ██║
██╔══██╗██╔══╝  ╚════██║   ██║   ██╔══██╗██║██║        ██║   ██╔══╝  ██║  ██║
██║  ██║███████╗███████║   ██║   ██║  ██║██║╚██████╗   ██║   ███████╗██████╔╝
╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝ ╚═════╝   ╚═╝   ╚══════╝╚═════╝ 
                                                                             
██╗  ██╗███████╗██████╗  ██████╗██████╗  ██████╗                             
╚██╗██╔╝██╔════╝██╔══██╗██╔════╝╚════██╗██╔═████╗                            
 ╚███╔╝ █████╗  ██████╔╝██║      █████╔╝██║██╔██║                            
 ██╔██╗ ██╔══╝  ██╔══██╗██║     ██╔═══╝ ████╔╝██║                            
██╔╝ ██╗███████╗██║  ██║╚██████╗███████╗╚██████╔╝                            
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚══════╝ ╚═════╝                                                       

*/

/// @title RestrictedXERC20
/// @notice Identical to XERC20, but with a permissioned transfer function
/// @dev Restrictions apply to all chains except the origin chain (i.e. optimism)
contract RestrictedXERC20 is XERC20, IRestrictedXERC20 {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc IRestrictedXERC20
    uint256 public constant UNRESTRICTED_CHAIN_ID = 10;
    /// @inheritdoc IRestrictedXERC20
    bytes11 public constant TOKEN_BRIDGE_ENTROPY = 0x0020000000000000000014;
    /// @inheritdoc IRestrictedXERC20
    address public immutable tokenBridge;

    // Set of whitelisted contracts that can transfer tokens
    EnumerableSet.AddressSet internal _whitelist;

    constructor(string memory _name, string memory _symbol, address _owner, address _lockbox)
        XERC20(_name, _symbol, _owner, _lockbox)
    {
        tokenBridge = CreateXLibrary.computeCreate3Address({_entropy: TOKEN_BRIDGE_ENTROPY, _deployer: tx.origin});
        // Not necessary to whitelist but done for consistency
        _whitelist.add(tokenBridge);
    }

    /// @inheritdoc IRestrictedXERC20
    function whitelist() external view returns (address[] memory) {
        return _whitelist.values();
    }

    /// @inheritdoc IRestrictedXERC20
    function whitelistLength() external view returns (uint256) {
        return _whitelist.length();
    }

    /// @dev Transfers operate normally on the origin chain
    /// @dev On other chains, transfers are restricted to the token bridge and whitelisted addresses
    /// @dev Transfer destinations from the token bridge will automatically be whitelisted
    function _update(address _from, address _to, uint256 _value) internal override {
        if (block.chainid != UNRESTRICTED_CHAIN_ID) {
            // Allow mints and burns
            if (_from != address(0) && _to != address(0)) {
                if (_from == tokenBridge) {
                    _whitelist.add(_to);
                } else if (!_whitelist.contains(_from)) {
                    revert NotWhitelisted();
                }
            }
        }

        super._update({from: _from, to: _to, value: _value});
    }
}
