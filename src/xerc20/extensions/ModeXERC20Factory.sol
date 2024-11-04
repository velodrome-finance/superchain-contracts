// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {ModeXERC20} from "./ModeXERC20.sol";
import {ModeFeeSharing} from "../../extensions/ModeFeeSharing.sol";
import {IXERC20Factory, XERC20Factory, CreateXLibrary} from "../XERC20Factory.sol";

/// @notice xERC-20 factory wrapper with fee sharing support
contract ModeXERC20Factory is XERC20Factory, ModeFeeSharing {
    using CreateXLibrary for bytes11;

    constructor(address _owner, address _erc20, address _recipient)
        XERC20Factory(_owner, _erc20)
        ModeFeeSharing(_recipient)
    {}

    /// @inheritdoc IXERC20Factory
    function deployXERC20() external override returns (address _XERC20) {
        if (block.chainid == 10) revert InvalidChainId();

        _XERC20 = CreateXLibrary.CREATEX.deployCreate3({
            salt: XERC20_ENTROPY.calculateSalt({_deployer: address(this)}),
            initCode: abi.encodePacked(
                type(ModeXERC20).creationCode,
                abi.encode(
                    name, // name of xerc20
                    symbol, // symbol of xerc20
                    owner, // owner of xerc20
                    address(0), // no lockbox
                    sfs, // sequencer fee sharing contract
                    tokenId // token id that sequencer fees are sent to
                )
            )
        });

        emit DeployXERC20({_xerc20: _XERC20});
    }
}
