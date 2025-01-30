// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../DeployFixture.sol";
import {RestrictedXERC20Factory} from "src/xerc20/extensions/RestrictedXERC20Factory.sol";
import {RestrictedXERC20} from "src/xerc20/extensions/RestrictedXERC20.sol";
import {XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";
import {RootRestrictedTokenBridge} from "src/root/bridge/RootRestrictedTokenBridge.sol";

contract DeployRootRestrictedXERC20 is DeployFixture {
    using CreateXLibrary for bytes11;

    struct RestrictedXERC20DeploymentParams {
        address owner;
        address incentiveToken;
        address module;
        address ism;
        string outputFilename;
    }

    RestrictedXERC20Factory public rootRestrictedXFactory;
    RestrictedXERC20 public rootRestrictedRewardToken;
    XERC20Lockbox public rootRestrictedRewardLockbox;
    RootRestrictedTokenBridge public rootRestrictedTokenBridge;

    RestrictedXERC20DeploymentParams internal _params;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    function deploy() internal virtual override {
        address _deployer = deployer;

        rootRestrictedXFactory = RestrictedXERC20Factory(
            cx.deployCreate3({
                salt: XOP_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RestrictedXERC20Factory).creationCode,
                    abi.encode(
                        _params.owner, // owner
                        _params.incentiveToken // incentive token
                    )
                )
            })
        );
        checkAddress({_entropy: XOP_FACTORY_ENTROPY, _output: address(rootRestrictedXFactory)});

        (address _restrictedRewardToken, address _restrictedRewardLockbox) =
            rootRestrictedXFactory.deployXERC20WithLockbox();

        rootRestrictedRewardToken = RestrictedXERC20(_restrictedRewardToken);
        rootRestrictedRewardLockbox = XERC20Lockbox(_restrictedRewardLockbox);

        rootRestrictedTokenBridge = RootRestrictedTokenBridge(
            cx.deployCreate3({
                salt: XOP_TOKEN_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RootRestrictedTokenBridge).creationCode,
                    abi.encode(
                        _params.owner, // token bridge owner
                        address(rootRestrictedRewardToken), // token associated with bridge
                        _params.module, // origin hyperlane module
                        _params.ism // hyperlane ism
                    )
                )
            })
        );
        checkAddress({_entropy: XOP_TOKEN_BRIDGE_ENTROPY, _output: address(rootRestrictedTokenBridge)});
    }

    function params() external view returns (RestrictedXERC20DeploymentParams memory) {
        return _params;
    }

    function logParams() internal view override {
        console.log("rootRestrictedXFactory: ", address(rootRestrictedXFactory));
        console.log("rootRestrictedRewardToken: ", address(rootRestrictedRewardToken));
        console.log("rootRestrictedRewardLockbox: ", address(rootRestrictedRewardLockbox));
        console.log("rootRestrictedTokenBridge: ", address(rootRestrictedTokenBridge));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        vm.writeJson(vm.serializeAddress("", "rootRestrictedXFactory", address(rootRestrictedXFactory)), path);
        vm.writeJson(vm.serializeAddress("", "rootRestrictedRewardToken", address(rootRestrictedRewardToken)), path);
        vm.writeJson(vm.serializeAddress("", "rootRestrictedRewardLockbox", address(rootRestrictedRewardLockbox)), path);
        vm.writeJson(vm.serializeAddress("", "rootRestrictedTokenBridge", address(rootRestrictedTokenBridge)), path);
    }

    function setUp() public virtual override {}
}
