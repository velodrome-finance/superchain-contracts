// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../DeployFixture.sol";
import {RestrictedXERC20Factory} from "src/xerc20/extensions/RestrictedXERC20Factory.sol";
import {RestrictedXERC20} from "src/xerc20/extensions/RestrictedXERC20.sol";
import {LeafRestrictedTokenBridge} from "src/bridge/LeafRestrictedTokenBridge.sol";

contract DeployLeafRestrictedXERC20 is DeployFixture {
    using CreateXLibrary for bytes11;

    struct RestrictedXERC20DeploymentParams {
        address owner;
        address mailbox;
        address ism;
        address voter;
        string outputFilename;
    }

    RestrictedXERC20Factory public leafRestrictedXFactory;
    RestrictedXERC20 public leafRestrictedRewardToken;
    LeafRestrictedTokenBridge public leafRestrictedTokenBridge;

    RestrictedXERC20DeploymentParams internal _params;

    /// @dev Used by tests to disable logging of output
    bool public isTest;

    function deploy() internal virtual override {
        address _deployer = deployer;

        leafRestrictedXFactory = RestrictedXERC20Factory(
            cx.deployCreate3({
                salt: XOP_FACTORY_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(RestrictedXERC20Factory).creationCode,
                    abi.encode(
                        _params.owner, // xerc20 owner
                        address(0) // no incentive token for leaf
                    )
                )
            })
        );
        checkAddress({_entropy: XOP_FACTORY_ENTROPY, _output: address(leafRestrictedXFactory)});

        leafRestrictedRewardToken = RestrictedXERC20(leafRestrictedXFactory.deployXERC20());

        leafRestrictedTokenBridge = LeafRestrictedTokenBridge(
            cx.deployCreate3({
                salt: XOP_TOKEN_BRIDGE_ENTROPY.calculateSalt({_deployer: _deployer}),
                initCode: abi.encodePacked(
                    type(LeafRestrictedTokenBridge).creationCode,
                    abi.encode(
                        _params.owner, // token bridge owner
                        address(leafRestrictedRewardToken), // token associated with bridge
                        _params.mailbox, // hyperlane mailbox
                        _params.ism, // hyperlane ism
                        _params.voter // voter address
                    )
                )
            })
        );
        checkAddress({_entropy: XOP_TOKEN_BRIDGE_ENTROPY, _output: address(leafRestrictedTokenBridge)});
    }

    function params() external view returns (RestrictedXERC20DeploymentParams memory) {
        return _params;
    }

    function logParams() internal view override {
        console.log("leafRestrictedXFactory: ", address(leafRestrictedXFactory));
        console.log("leafRestrictedRewardToken: ", address(leafRestrictedRewardToken));
        console.log("leafRestrictedTokenBridge: ", address(leafRestrictedTokenBridge));
    }

    function logOutput() internal override {
        if (isTest) return;
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses/", _params.outputFilename));
        vm.writeJson(vm.toString(address(leafRestrictedXFactory)), path, ".leafRestrictedXFactory");
        vm.writeJson(vm.toString(address(leafRestrictedRewardToken)), path, ".leafRestrictedRewardToken");
        vm.writeJson(vm.toString(address(leafRestrictedTokenBridge)), path, ".leafRestrictedTokenBridge");
    }

    function setUp() public virtual override {}
}
