// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReward {
    function getReward(uint256 _tokenId, address[] memory _tokens) external;
}
