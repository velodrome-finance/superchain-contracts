// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import {IFactoryRegistry} from "src/interfaces/external/IFactoryRegistry.sol";
import {EnumerableSet} from "@openzeppelin5/contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockFactoryRegistry is Ownable, IFactoryRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _poolFactories;

    struct FactoriesToPoolFactory {
        address votingRewardsFactory;
        address gaugeFactory;
    }

    mapping(address => FactoriesToPoolFactory) private _factoriesToPoolsFactory;

    function approve(address poolFactory, address votingRewardsFactory, address gaugeFactory) public override {
        require(!_poolFactories.contains(poolFactory));
        _poolFactories.add(poolFactory);
        _factoriesToPoolsFactory[poolFactory] =
            FactoriesToPoolFactory({votingRewardsFactory: votingRewardsFactory, gaugeFactory: gaugeFactory});
    }

    function isPoolFactoryApproved(address poolFactory) external view override returns (bool) {
        return _poolFactories.contains(poolFactory);
    }

    function factoriesToPoolFactory(address poolFactory)
        public
        view
        override
        returns (address votingRewardsFactory, address gaugeFactory)
    {
        FactoriesToPoolFactory memory f = _factoriesToPoolsFactory[poolFactory];
        votingRewardsFactory = f.votingRewardsFactory;
        gaugeFactory = f.gaugeFactory;
    }
}
