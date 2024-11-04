// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <0.9.0;

import {IERC20} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin5/contracts/token/ERC20/utils/SafeERC20.sol";

import {IXERC20} from "../interfaces/xerc20/IXERC20.sol";
import {IXERC20Lockbox} from "../interfaces/xerc20/IXERC20Lockbox.sol";

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

██╗  ██╗███████╗██████╗  ██████╗██████╗  ██████╗ ██╗      ██████╗  ██████╗██╗  ██╗██████╗  ██████╗ ██╗  ██╗
╚██╗██╔╝██╔════╝██╔══██╗██╔════╝╚════██╗██╔═████╗██║     ██╔═══██╗██╔════╝██║ ██╔╝██╔══██╗██╔═══██╗╚██╗██╔╝
 ╚███╔╝ █████╗  ██████╔╝██║      █████╔╝██║██╔██║██║     ██║   ██║██║     █████╔╝ ██████╔╝██║   ██║ ╚███╔╝
 ██╔██╗ ██╔══╝  ██╔══██╗██║     ██╔═══╝ ████╔╝██║██║     ██║   ██║██║     ██╔═██╗ ██╔══██╗██║   ██║ ██╔██╗
██╔╝ ██╗███████╗██║  ██║╚██████╗███████╗╚██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗██████╔╝╚██████╔╝██╔╝ ██╗
╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝

*/

/// @title XERC20Lockbox
/// @notice Lockbox to enable wrapping and unwrapping ERC20 into XERC20 tokens
contract XERC20Lockbox is IXERC20Lockbox {
    using SafeERC20 for IERC20;

    /// @inheritdoc IXERC20Lockbox
    IXERC20 public immutable XERC20;

    /// @inheritdoc IXERC20Lockbox
    IERC20 public immutable ERC20;

    /// @notice Constructor
    /// @param _xerc20 The address of the XERC20 contract
    /// @param _erc20 The address of the ERC20 contract
    constructor(address _xerc20, address _erc20) {
        XERC20 = IXERC20(_xerc20);
        ERC20 = IERC20(_erc20);
    }

    /// @inheritdoc IXERC20Lockbox
    function deposit(uint256 _amount) external {
        ERC20.safeTransferFrom(msg.sender, address(this), _amount);
        XERC20.mint(msg.sender, _amount);
        emit Deposit(msg.sender, _amount);
    }

    /// @inheritdoc IXERC20Lockbox
    function withdraw(uint256 _amount) external {
        XERC20.burn(msg.sender, _amount);
        ERC20.safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }
}
