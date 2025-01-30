// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/src/StdJson.sol";
import "forge-std/src/Script.sol";
import "forge-std/src/console.sol";

import {ICreateX} from "createX/ICreateX.sol";

import {CreateXLibrary} from "src/libraries/CreateXLibrary.sol";
import {Commands} from "src/libraries/Commands.sol";
import {GasLimits} from "src/libraries/GasLimits.sol";

import {Constants} from "script/constants/Constants.sol";

abstract contract DeployFixture is Script, Constants {
    using CreateXLibrary for bytes11;
    using GasLimits for uint256;

    error InvalidAddress(address expected, address output);

    ICreateX public cx = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    address public deployer = 0x4994DacdB9C57A811aFfbF878D92E00EF2E5C4C2;

    // Gas Router default commands and gas limits
    uint256[] defaultCommands = [
        Commands.DEPOSIT,
        Commands.WITHDRAW,
        Commands.GET_INCENTIVES,
        Commands.GET_FEES,
        Commands.CREATE_GAUGE,
        Commands.NOTIFY,
        Commands.NOTIFY_WITHOUT_CLAIM,
        Commands.KILL_GAUGE,
        Commands.REVIVE_GAUGE
    ];
    uint256[] defaultGasLimits = [
        Commands.DEPOSIT.gasLimit(),
        Commands.WITHDRAW.gasLimit(),
        Commands.GET_INCENTIVES.gasLimit(),
        Commands.GET_FEES.gasLimit(),
        Commands.CREATE_GAUGE.gasLimit(),
        Commands.NOTIFY.gasLimit(),
        Commands.NOTIFY_WITHOUT_CLAIM.gasLimit(),
        Commands.KILL_GAUGE.gasLimit(),
        Commands.REVIVE_GAUGE.gasLimit()
    ];

    function setUp() public virtual;

    function run() external {
        vm.startBroadcast(deployer);
        verifyCreate3();

        deploy();
        logParams();
        logOutput();

        vm.stopBroadcast();
    }

    function deploy() internal virtual;

    function logParams() internal view virtual;

    function logOutput() internal virtual;

    /// @dev Check if the computed address matches the address produced by the deployment
    function checkAddress(bytes11 _entropy, address _output) internal view {
        address computedAddress = _entropy.computeCreate3Address({_deployer: deployer});
        if (computedAddress != _output) {
            revert InvalidAddress(computedAddress, _output);
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
}
