// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../DeployFixture.sol";
import {RestrictedXERC20Factory} from "src/xerc20/extensions/RestrictedXERC20Factory.sol";
import {RestrictedXERC20} from "src/xerc20/extensions/RestrictedXERC20.sol";
import {XERC20Lockbox} from "src/xerc20/XERC20Lockbox.sol";
import {RootRestrictedTokenBridge} from "src/root/bridge/RootRestrictedTokenBridge.sol";
import {PaymasterVault} from "src/root/bridge/hyperlane/PaymasterVault.sol";

contract DeployRootRestrictedXERC20 is DeployFixture {
    using CreateXLibrary for bytes11;

    struct RestrictedXERC20DeploymentParams {
        address owner;
        address incentiveToken;
        address module;
        address weth;
        address ism;
        string outputFilename;
    }

    RestrictedXERC20Factory public rootRestrictedXFactory;
    RestrictedXERC20 public rootRestrictedRewardToken;
    XERC20Lockbox public rootRestrictedRewardLockbox;
    RootRestrictedTokenBridge public rootRestrictedTokenBridge;
    PaymasterVault public rootRestrictedTokenBridgeVault;

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

        rootRestrictedTokenBridge =
            RootRestrictedTokenBridge(payable(XOP_TOKEN_BRIDGE_ENTROPY.computeCreate3Address({_deployer: _deployer})));
        rootRestrictedTokenBridgeVault =
            new PaymasterVault({_owner: _params.owner, _vaultManager: address(rootRestrictedTokenBridge)});
        rootRestrictedTokenBridge = RootRestrictedTokenBridge(
            payable(
                cx.deployCreate3({
                    salt: XOP_TOKEN_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                    initCode: abi.encodePacked(
                        type(RootRestrictedTokenBridge).creationCode,
                        abi.encode(
                            _params.owner, // token bridge owner
                            address(rootRestrictedRewardToken), // token associated with bridge
                            _params.module, // origin hyperlane module
                            address(rootRestrictedTokenBridgeVault), // restricted token bridge paymaster vault
                            _params.ism // hyperlane ism
                        )
                    )
                })
            )
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
        console.log("rootRestrictedTokenBridgeVault: ", address(rootRestrictedTokenBridgeVault));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        vm.writeJson(vm.toString(address(rootRestrictedXFactory)), path, ".rootRestrictedXFactory");
        vm.writeJson(vm.toString(address(rootRestrictedRewardToken)), path, ".rootRestrictedRewardToken");
        vm.writeJson(vm.toString(address(rootRestrictedRewardLockbox)), path, ".rootRestrictedRewardLockbox");
        vm.writeJson(vm.toString(address(rootRestrictedTokenBridge)), path, ".rootRestrictedTokenBridge");
        vm.writeJson(vm.toString(address(rootRestrictedTokenBridgeVault)), path, ".rootRestrictedTokenBridgeVault");
    }

    function setUp() public virtual override {}
}
