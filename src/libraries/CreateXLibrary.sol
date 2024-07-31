// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {ICreateX} from "createX/ICreateX.sol";

library CreateXLibrary {
    ICreateX public constant CREATEX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    function calculateSalt(bytes11 _entropy, address _deployer) internal pure returns (bytes32 _salt) {
        _salt = bytes32(abi.encodePacked(bytes20(_deployer), bytes1(0x00), _entropy));
    }

    function computeCreate3Address(bytes11 _entropy, address _deployer) internal view returns (address _address) {
        bytes32 salt = calculateSalt({_entropy: _entropy, _deployer: _deployer});
        bytes32 guardedSalt = keccak256(abi.encodePacked(uint256(uint160(_deployer)), salt));
        _address = CREATEX.computeCreate3Address({salt: guardedSalt, deployer: address(CREATEX)});
    }
}
