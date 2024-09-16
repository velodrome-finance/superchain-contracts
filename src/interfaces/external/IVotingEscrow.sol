// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin5/contracts/token/ERC721/IERC721.sol";

interface IVotingEscrow is IERC721 {
    /// @notice Check whether spender is owner or an approved user for a given veNFT
    /// @param _spender .
    /// @param _tokenId .
    function isApprovedOrOwner(address _spender, uint256 _tokenId) external returns (bool);

    /// @notice Deposit `_value` tokens for `msg.sender` and lock for `_lockDuration`
    /// @param _value Amount to deposit
    /// @param _lockDuration Number of seconds to lock tokens for (rounded down to nearest week)
    /// @return TokenId of created veNFT
    function createLock(uint256 _value, uint256 _lockDuration) external returns (uint256);

    /// @notice Get the voting power for _tokenId at the current timestamp
    /// @dev Returns 0 if called in the same block as a transfer.
    /// @param _tokenId .
    /// @return Voting power
    function balanceOfNFT(uint256 _tokenId) external view returns (uint256);

    /// @notice Set Managed NFT state. Inactive NFTs cannot be deposited into.
    /// @param _mTokenId managed nft state to set
    /// @param _state true => inactive, false => active
    function setManagedState(uint256 _mTokenId, bool _state) external;

    function deactivated(uint256 _mTokenId) external view returns (bool);
}
