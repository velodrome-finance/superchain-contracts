// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ICreateX} from "createX/ICreateX.sol";

import {XERC20} from "./XERC20.sol";
import {IXERC20Factory} from "../interfaces/xerc20/IXERC20Factory.sol";
import {XERC20Lockbox} from "./XERC20Lockbox.sol";
import {CreateXLibrary} from "../libraries/CreateXLibrary.sol";

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

██╗  ██╗███████╗██████╗  ██████╗██████╗  ██████╗ ███████╗ █████╗  ██████╗████████╗ ██████╗ ██████╗ ██╗   ██╗
╚██╗██╔╝██╔════╝██╔══██╗██╔════╝╚════██╗██╔═████╗██╔════╝██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗╚██╗ ██╔╝
 ╚███╔╝ █████╗  ██████╔╝██║      █████╔╝██║██╔██║█████╗  ███████║██║        ██║   ██║   ██║██████╔╝ ╚████╔╝
 ██╔██╗ ██╔══╝  ██╔══██╗██║     ██╔═══╝ ████╔╝██║██╔══╝  ██╔══██║██║        ██║   ██║   ██║██╔══██╗  ╚██╔╝
██╔╝ ██╗███████╗██║  ██║╚██████╗███████╗╚██████╔╝██║     ██║  ██║╚██████╗   ██║   ╚██████╔╝██║  ██║   ██║
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚══════╝ ╚═════╝ ╚═╝     ╚═╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝

*/

/// @title XERC20Factory
/// @notice Deploys a canonical XERC20 on each chain
/// @dev Depends on CreateX, assumes bytecode for CreateX has already been checked prior to deployment
contract XERC20Factory is IXERC20Factory {
    using CreateXLibrary for bytes11;

    /// @inheritdoc IXERC20Factory
    address public immutable owner;

    /// @inheritdoc IXERC20Factory
    string public constant name = "Superchain Velodrome";
    /// @inheritdoc IXERC20Factory
    string public constant symbol = "XVELO";

    /// @inheritdoc IXERC20Factory
    bytes11 public constant XERC20_ENTROPY = 0x0000000000000000000000;
    /// @inheritdoc IXERC20Factory
    bytes11 public constant LOCKBOX_ENTROPY = 0x0000000000000000000001;

    /// @notice Constructs the initial config of the XERC20Factory
    /// @param _owner The address of the initial owner for XERC20 deployments
    constructor(address _owner) {
        if (_owner == address(0)) revert ZeroAddress();
        owner = _owner;
    }

    /// @inheritdoc IXERC20Factory
    function deployXERC20() external virtual returns (address _XERC20) {
        if (block.chainid == 10) revert InvalidChainId();

        _XERC20 = CreateXLibrary.CREATEX.deployCreate3({
            salt: XERC20_ENTROPY.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(XERC20).creationCode,
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
    function deployXERC20WithLockbox(address _erc20) external returns (address _XERC20, address _lockbox) {
        if (block.chainid != 10) revert InvalidChainId();

        address expectedAddress = XERC20_ENTROPY.computeCreate3Address({_deployer: address(this)});

        _lockbox = CreateXLibrary.CREATEX.deployCreate3({
            salt: LOCKBOX_ENTROPY.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(XERC20Lockbox).creationCode,
                abi.encode(
                    expectedAddress, // xerc20 address
                    _erc20 // erc20 address
                )
            )
        });

        _XERC20 = CreateXLibrary.CREATEX.deployCreate3({
            salt: XERC20_ENTROPY.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(XERC20).creationCode,
                abi.encode(
                    name, // name of xerc20
                    symbol, // symbol of xerc20
                    owner, // owner of xerc20
                    _lockbox // lockbox corresponding to xerc20
                )
            )
        });

        assert(_XERC20 == expectedAddress);

        emit DeployXERC20WithLockbox({_xerc20: _XERC20, _lockbox: _lockbox});
    }
}
