// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {ICreateX} from "createX/ICreateX.sol";

import {XERC20} from "./XERC20.sol";
import {IXERC20Factory} from "../interfaces/xerc20/IXERC20Factory.sol";
import {XERC20Lockbox} from "./XERC20Lockbox.sol";

/// @title XERC20Factory contract that deploys a canonical XERC20 on each chain
/// @dev Depends on CreateX, assumes bytecode for CreateX has already been checked prior to deployment
contract XERC20Factory is IXERC20Factory {
    /// @inheritdoc IXERC20Factory
    ICreateX public immutable createx;

    /// @inheritdoc IXERC20Factory
    string public constant name = "Superchain Velodrome";
    /// @inheritdoc IXERC20Factory
    string public constant symbol = "XVELO";

    /// @inheritdoc IXERC20Factory
    bytes11 public constant XERC20_ENTROPY = 0x0000000000000000000000;
    /// @inheritdoc IXERC20Factory
    bytes11 public constant LOCKBOX_ENTROPY = 0x0000000000000000000001;

    constructor(address _createx) {
        createx = ICreateX(_createx);
    }

    /// @inheritdoc IXERC20Factory
    function deployXERC20() external returns (address _XERC20) {
        if (block.chainid == 10) revert InvalidChainId();

        _XERC20 = createx.deployCreate3({
            salt: calculateSalt(XERC20_ENTROPY),
            initCode: abi.encodePacked(
                type(XERC20).creationCode,
                abi.encode(
                    name, // name of xerc20
                    symbol, // symbol of xerc20
                    address(this) // owner of xerc20
                )
            )
        });

        emit DeployXERC20({_xerc20: _XERC20});
    }

    /// @inheritdoc IXERC20Factory
    function deployXERC20WithLockbox(address _erc20) external returns (address _XERC20, address _lockbox) {
        if (block.chainid != 10) revert InvalidChainId();

        // precompute xerc20 address
        bytes32 guardedSalt =
            keccak256(abi.encodePacked(uint256(uint160(address(this))), calculateSalt(XERC20_ENTROPY)));
        address expectedAddress = createx.computeCreate3Address({salt: guardedSalt, deployer: address(createx)});

        _lockbox = createx.deployCreate3({
            salt: calculateSalt(LOCKBOX_ENTROPY),
            initCode: abi.encodePacked(
                type(XERC20Lockbox).creationCode,
                abi.encode(
                    expectedAddress, // xerc20 address
                    _erc20 // erc20 address
                )
            )
        });

        _XERC20 = createx.deployCreate3({
            salt: calculateSalt(XERC20_ENTROPY),
            initCode: abi.encodePacked(
                type(XERC20).creationCode,
                abi.encode(
                    name, // name of xerc20
                    symbol, // symbol of xerc20
                    address(this) // owner of xerc20
                )
            )
        });
        XERC20(_XERC20).setLockbox({_lockbox: _lockbox});

        assert(_XERC20 == expectedAddress);

        emit DeployXERC20WithLockbox({_xerc20: _XERC20, _lockbox: _lockbox});
    }

    function calculateSalt(bytes11 _entropy) internal view returns (bytes32 salt) {
        salt = bytes32(abi.encodePacked(bytes20(address(this)), bytes1(0x00), _entropy));
    }
}
