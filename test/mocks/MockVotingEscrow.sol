// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ERC721} from "@openzeppelin5/contracts/token/ERC721/ERC721.sol";

import {IVotingEscrow} from "src/interfaces/external/IVotingEscrow.sol";

contract MockVotingEscrow is IVotingEscrow, ERC721 {
    uint256 public tokenId;

    constructor() ERC721("veNFT", "veNFT") {}

    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool) {
        address owner = _ownerOf(_tokenId);
        return _isAuthorized(owner, _spender, _tokenId);
    }

    function createLock(uint256, uint256) external override returns (uint256) {
        _mint(msg.sender, ++tokenId);
        return tokenId;
    }
}
