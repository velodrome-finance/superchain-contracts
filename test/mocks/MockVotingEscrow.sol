// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ERC721} from "@openzeppelin5/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin5/contracts/token/ERC20/ERC20.sol";

import {IVotingEscrow} from "src/interfaces/external/IVotingEscrow.sol";

contract MockVotingEscrow is IVotingEscrow, ERC721 {
    uint256 public tokenId;
    mapping(uint256 => bool) public override deactivated;
    mapping(uint256 => uint256) internal _balanceOfNFT;
    IERC20 public token;

    constructor(address _token) ERC721("veNFT", "veNFT") {
        token = IERC20(_token);
    }

    function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool) {
        address owner = _ownerOf(_tokenId);
        return _isAuthorized(owner, _spender, _tokenId);
    }

    function createLock(uint256 _value, uint256) external override returns (uint256) {
        _mint(msg.sender, ++tokenId);
        _balanceOfNFT[tokenId] = _value;
        return tokenId;
    }

    function balanceOfNFT(uint256 _tokenId) public view returns (uint256) {
        return _balanceOfNFT[_tokenId];
    }

    function setManagedState(uint256 _mTokenId, bool _state) external override {
        deactivated[_mTokenId] = _state;
    }

    function depositFor(uint256 _tokenId, uint256 _value) external {
        if (ownerOf(_tokenId) == address(0)) {
            revert("Token does not exist");
        }
        token.transferFrom(msg.sender, address(this), _value);
        _balanceOfNFT[_tokenId] += _value;
    }
}
