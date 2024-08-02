// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ERC20} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin5/contracts/interfaces/IERC20Metadata.sol";

/// @notice Simple ERC20 implementation
contract TestERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint256 decimals_) ERC20(name_, symbol_) {
        _decimals = uint8(decimals_);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
