// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {ICreateX} from "createX/ICreateX.sol";

import {RestrictedXERC20} from "./RestrictedXERC20.sol";
import {IXERC20Factory} from "../../interfaces/xerc20/IXERC20Factory.sol";
import {XERC20Lockbox} from "../XERC20Lockbox.sol";
import {CreateXLibrary} from "../../libraries/CreateXLibrary.sol";

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
                                                                                                            
██╗  ██╗███████╗██████╗  ██████╗██████╗  ██████╗ ███████╗ █████╗  ██████╗████████╗ ██████╗ ██████╗ ██╗   ██╗
╚██╗██╔╝██╔════╝██╔══██╗██╔════╝╚════██╗██╔═████╗██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗╚██╗ ██╔╝
 ╚███╔╝ █████╗  ██████╔╝██║      █████╔╝██║██╔██║█████╗  ███████║██║        ██║   ██║   ██║██████╔╝ ╚████╔╝ 
 ██╔██╗ ██╔══╝  ██╔══██╗██║     ██╔═══╝ ████╔╝██║██╔══╝  ██╔══██║██║        ██║   ██║   ██║██╔══██╗  ╚██╔╝  
██╔╝ ██╗███████╗██║  ██║╚██████╗███████╗╚██████╔╝██║     ██║  ██║╚██████╗   ██║   ╚██████╔╝██║  ██║   ██║   
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚══════╝ ╚═════╝ ╚═╝     ╚═╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝   

*/

/// @title RestrictedXERC20Factory
/// @notice Identical to XERC20Factory, but with a restricted XERC20 implementation
/// @dev Depends on CreateX, assumes bytecode for CreateX has already been checked prior to deployment
/// @dev Supports 18 decimal tokens only. Pass in the erc20 address on root to create a lockbox for it.
contract RestrictedXERC20Factory is IXERC20Factory {
    using CreateXLibrary for bytes11;

    /// @inheritdoc IXERC20Factory
    address public immutable owner;
    /// @inheritdoc IXERC20Factory
    address public immutable erc20;

    /// @inheritdoc IXERC20Factory
    string public constant name = "Superchain OP";
    /// @inheritdoc IXERC20Factory
    string public constant symbol = "XOP";

    /// @inheritdoc IXERC20Factory
    bytes11 public constant XERC20_ENTROPY = 0x0000000000000000000000;
    /// @inheritdoc IXERC20Factory
    bytes11 public constant LOCKBOX_ENTROPY = 0x0000000000000000000001;

    /// @notice Constructs the initial config of the XERC20Factory
    /// @param _owner The address of the initial owner for XERC20 deployments
    constructor(address _owner, address _erc20) {
        if (_owner == address(0)) revert ZeroAddress();
        owner = _owner;
        erc20 = _erc20;
    }

    /// @inheritdoc IXERC20Factory
    function deployXERC20() external virtual returns (address _XERC20) {
        if (block.chainid == 10) revert InvalidChainId();

        _XERC20 = CreateXLibrary.CREATEX.deployCreate3({
            salt: XERC20_ENTROPY.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(RestrictedXERC20).creationCode,
                abi.encode(
                    name, // name of xerc20
                    symbol, // symbol of xerc20
                    owner, // owner of xerc20
                    address(0) // no lockbox
                )
            )
        });

        emit DeployXERC20({_xerc20: _XERC20});
    }

    /// @inheritdoc IXERC20Factory
    function deployXERC20WithLockbox() external returns (address _XERC20, address _lockbox) {
        if (block.chainid != 10) revert InvalidChainId();

        address expectedAddress = XERC20_ENTROPY.computeCreate3Address({_deployer: address(this)});

        _lockbox = CreateXLibrary.CREATEX.deployCreate3({
            salt: LOCKBOX_ENTROPY.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(XERC20Lockbox).creationCode,
                abi.encode(
                    expectedAddress, // xerc20 address
                    erc20 // erc20 address
                )
            )
        });

        _XERC20 = CreateXLibrary.CREATEX.deployCreate3({
            salt: XERC20_ENTROPY.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(RestrictedXERC20).creationCode,
                abi.encode(
                    name, // name of xerc20
                    symbol, // symbol of xerc20
                    owner, // owner of xerc20
                    _lockbox // lockbox corresponding to xerc20
                )
            )
        });

        emit DeployXERC20WithLockbox({_xerc20: _XERC20, _lockbox: _lockbox});
    }
}
