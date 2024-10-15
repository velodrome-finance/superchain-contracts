// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../RootPoolFactory.t.sol";

contract CreatePoolIntegrationConcreteTest is RootPoolFactoryTest {
    TestERC20 public tokenA;
    TestERC20 public tokenB;

    uint256 _chainid = 1_000;

    function setUp() public override {
        super.setUp();

        tokenA = new TestERC20("Test Token A", "TTA", 18);
        tokenB = new TestERC20("Test Token B", "TTB", 6); // mimic USDC
    }

    function test_WhenChainIdIsNotRegistered() external {
        // It reverts with {ChainNotRegistered}
        vm.expectRevert(ICrossChainRegistry.ChainNotRegistered.selector);
        rootPoolFactory.createPool({chainid: _chainid, tokenA: address(tokenA), tokenB: address(tokenB), stable: true});
    }

    modifier whenChainIdIsRegistered() {
        vm.prank(users.owner);
        rootMessageBridge.registerChain({_chainid: _chainid, _module: address(rootMessageModule)});
        _;
    }

    function test_WhenTokenAIsTheSameAsTokenB() external whenChainIdIsRegistered {
        // It reverts with {SameAddress}
        vm.expectRevert(IRootPoolFactory.SameAddress.selector);
        rootPoolFactory.createPool({chainid: _chainid, tokenA: address(tokenA), tokenB: address(tokenA), stable: true});
    }

    modifier whenTokenAIsNotTheSameAsTokenB() {
        _;
    }

    function test_WhenToken0IsTheZeroAddress() external whenChainIdIsRegistered whenTokenAIsNotTheSameAsTokenB {
        // It reverts with {ZeroAddress}
        (, address token1) = tokenA < tokenB ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        vm.expectRevert(IRootPoolFactory.ZeroAddress.selector);
        rootPoolFactory.createPool({chainid: _chainid, tokenA: address(0), tokenB: address(token1), stable: true});
    }

    modifier whenToken0IsNotTheZeroAddress() {
        _;
    }

    function test_WhenThePoolAlreadyExists()
        external
        whenChainIdIsRegistered
        whenTokenAIsNotTheSameAsTokenB
        whenToken0IsNotTheZeroAddress
    {
        // It reverts with {PoolAlreadyExists}
        rootPoolFactory.createPool({chainid: _chainid, tokenA: address(tokenA), tokenB: address(tokenB), stable: true});

        vm.expectRevert(IRootPoolFactory.PoolAlreadyExists.selector);
        rootPoolFactory.createPool({chainid: _chainid, tokenA: address(tokenA), tokenB: address(tokenB), stable: true});
    }

    function test_WhenThePoolDoesNotExist()
        external
        whenChainIdIsRegistered
        whenTokenAIsNotTheSameAsTokenB
        whenToken0IsNotTheZeroAddress
    {
        // It creates the pool using Create2
        // It populates the getPool mapping in both directions
        // It adds the pool to the list of all pools
        // It emits {PoolCreated}
        address pool = rootPoolFactory.createPool({
            chainid: _chainid,
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            stable: true
        });

        (address token0, address token1) =
            tokenA < tokenB ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        address expected = Clones.predictDeterministicAddress({
            implementation: rootPoolFactory.implementation(),
            salt: keccak256(abi.encodePacked(_chainid, token0, token1, true)),
            deployer: address(rootPoolFactory)
        });

        assertEq(pool, expected);
        assertEq(
            rootPoolFactory.getPool({chainid: _chainid, tokenA: address(tokenA), tokenB: address(tokenB), stable: true}),
            pool
        );
        assertEq(
            rootPoolFactory.getPool({chainid: _chainid, tokenA: address(tokenB), tokenB: address(tokenA), stable: true}),
            pool
        );
        assertEq(rootPoolFactory.allPools(2), pool);
    }

    function testGas_createPool()
        external
        whenChainIdIsRegistered
        whenTokenAIsNotTheSameAsTokenB
        whenToken0IsNotTheZeroAddress
    {
        rootPoolFactory.createPool({chainid: _chainid, tokenA: address(tokenA), tokenB: address(tokenB), stable: true});
        snapLastCall("RootPoolFactory_createPool");
    }
}
