// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "./DeployFixture.sol";

abstract contract DeployStakingFixture is DeployFixture {
    struct DeploymentParameters {
        address router;
        address keeperAdmin;
        address notifyAdmin;
        address admin;
        address rewardToken;
        address tokenRegistry;
        string outputFilename;
    }

    // deployed
    StakingRewardsFactory public stakingRewardsFactory;

    DeploymentParameters internal _params;

    /// @dev Override if deploying extensions
    function deploy() internal virtual override {
        stakingRewardsFactory = new StakingRewardsFactory({
            _admin: _params.admin,
            _notifyAdmin: _params.notifyAdmin,
            _keeperAdmin: _params.keeperAdmin,
            _tokenRegistry: _params.tokenRegistry,
            _rewardToken: _params.rewardToken,
            _router: _params.router,
            _keepers: new address[](0)
        });
    }

    function params() external view returns (DeploymentParameters memory) {
        return _params;
    }

    function logParams() internal view override {
        console2.log("stakingRewardsFactory: ", address(stakingRewardsFactory));
    }

    function logOutput() internal override {
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/deployment-addresses", _params.outputFilename));
        /// @dev This might overwrite an existing output file
        vm.writeJson(
            path,
            string(abi.encodePacked(stdJson.serialize("", "stakingRewardsFactory", address(stakingRewardsFactory))))
        );
    }
}
