// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "forge-std/Test.sol";
import {IPool, Pool} from "src/pools/Pool.sol";
import {IPoolFactory, PoolFactory} from "src/pools/PoolFactory.sol";
import {Users} from "./utils/Users.sol";
import {Constants} from "./utils/Constants.sol";
import {TestERC20} from "./mocks/TestERC20.sol";

abstract contract BaseFixture is Test, Constants {
    PoolFactory public poolFactory;
    Pool public poolImplementation;
    TestERC20 public rewardToken;

    TestERC20 public token0;
    TestERC20 public token1;

    Users internal users;

    function setUp() public virtual {
        users = Users({
            owner: createUser("Owner"),
            feeManager: createUser("FeeManager"),
            alice: createUser("Alice"),
            bob: createUser("Bob"),
            charlie: createUser("Charlie")
        });

        // run deployments as address(this)
        // at end of deployment, address(this) should have no ownership
        rewardToken = new TestERC20("Reward Token", "RWRD");

        TestERC20 tokenA = new TestERC20("Test Token A", "TTA");
        TestERC20 tokenB = new TestERC20("Test Token B", "TTB");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        poolImplementation = new Pool();
        poolFactory = new PoolFactory({_implementation: address(poolImplementation)});

        poolFactory.setPoolAdmin({_poolAdmin: users.owner});
        poolFactory.setPauser({_pauser: users.owner});
        poolFactory.setFeeManager({_feeManager: users.feeManager});

        labelContracts();
    }

    function labelContracts() public virtual {
        vm.label(address(poolImplementation), "Pool Implementation");
        vm.label(address(poolFactory), "Pool Factory");
    }

    function createUser(string memory name) internal returns (address payable user) {
        user = payable(makeAddr({name: name}));
        vm.deal({account: user, newBalance: TOKEN_1 * 1_000});
    }
}
