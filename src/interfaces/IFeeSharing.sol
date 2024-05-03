// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

interface IFeeSharing {
    function assign(uint256 _tokenId) external returns (uint256);
    function register(address _recipient) external returns (uint256);
}
