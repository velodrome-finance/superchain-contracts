// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ICreateX} from "createX/ICreateX.sol";

abstract contract DeployFixture is Script {
    error InvalidAddress(address expected, address output);

    ICreateX public cx = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    address public deployer = 0x4994DacdB9C57A811aFfbF878D92E00EF2E5C4C2;

    function setUp() public virtual;

    function run() external {
        vm.startBroadcast(deployer);
        verifyCreate3();

        deploy();
        logParams();

        vm.stopBroadcast();
    }

    function deploy() internal virtual;

    function logParams() internal view virtual;

    function logOutput() internal virtual;

    /// @dev Check if the computed address matches the address produced by the deployment
    function checkAddress(bytes32 salt, address output) internal view {
        bytes32 guardedSalt = keccak256(abi.encodePacked(uint256(uint160(deployer)), salt));
        address computedAddress = cx.computeCreate3Address({salt: guardedSalt, deployer: address(cx)});
        if (computedAddress != output) {
            revert InvalidAddress(computedAddress, output);
        }
    }

    function verifyCreate3() internal view {
        /// if not run locally
        if (block.chainid != 31337) {
            uint256 size;
            address contractAddress = address(cx);
            assembly {
                size := extcodesize(contractAddress)
            }

            bytes memory bytecode = new bytes(size);
            assembly {
                extcodecopy(contractAddress, add(bytecode, 32), 0, size)
            }

            assert(keccak256(bytecode) == bytes32(0xbd8a7ea8cfca7b4e5f5041d7d4b17bc317c5ce42cfbc42066a00cf26b43eb53f));
        }
    }

    function calculateSalt(bytes11 entropy) internal view returns (bytes32 salt) {
        salt = bytes32(abi.encodePacked(bytes20(deployer), bytes1(0x00), bytes11(entropy)));
    }
}
