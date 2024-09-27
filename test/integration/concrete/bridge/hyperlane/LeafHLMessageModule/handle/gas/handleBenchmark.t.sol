// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../LeafHLMessageModule.t.sol";

contract HandleBenchmarksIntegrationConcreteTest is LeafHLMessageModuleTest, GasSnapshot {
    uint32 public origin;
    bytes32 public sender;
    TestERC20 public tokenA;
    TestERC20 public tokenB;

    function setUp() public override {
        super.setUp();

        vm.selectFork({forkId: leafId});
        tokenA = new TestERC20("Test Token A", "TTA", 18);
        tokenB = new TestERC20("Test Token B", "TTB", 6); // mimic USDC

        // Notify rewards contracts
        deal(address(token0), address(leafGauge), TOKEN_1 * 2);
        deal(address(token1), address(leafGauge), TOKEN_1 * 2);
        // Using WETH, tokenA & tokenB as Bribe tokens
        deal(address(weth), address(leafGauge), TOKEN_1);
        deal(address(tokenA), address(leafGauge), TOKEN_1);
        deal(address(tokenB), address(leafGauge), TOKEN_1);
        vm.mockCall(
            address(leafVoter),
            abi.encodeWithSelector(IVoter.isWhitelistedToken.selector, address(tokenA)),
            abi.encode(true)
        );
        vm.mockCall(
            address(leafVoter),
            abi.encodeWithSelector(IVoter.isWhitelistedToken.selector, address(tokenB)),
            abi.encode(true)
        );

        vm.startPrank(address(leafGauge));
        token0.approve(address(leafFVR), TOKEN_1);
        token1.approve(address(leafFVR), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafFVR.notifyRewardAmount(address(token1), TOKEN_1);

        token0.approve(address(leafIVR), TOKEN_1);
        token1.approve(address(leafIVR), TOKEN_1);
        weth.approve(address(leafIVR), TOKEN_1);
        tokenA.approve(address(leafIVR), TOKEN_1);
        tokenB.approve(address(leafIVR), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token0), TOKEN_1);
        leafIVR.notifyRewardAmount(address(token1), TOKEN_1);
        leafIVR.notifyRewardAmount(address(weth), TOKEN_1);
        leafIVR.notifyRewardAmount(address(tokenA), TOKEN_1);
        leafIVR.notifyRewardAmount(address(tokenB), TOKEN_1);
        vm.stopPrank();

        /// @dev Use check mode to revert if snapshots are mismatched
        check = true;
        origin = 10;
        uint256 amountToBridge = TOKEN_1 * 1000;
        setLimits({_rootBufferCap: amountToBridge * 2, _leafBufferCap: amountToBridge * 2});

        sender = TypeCasts.addressToBytes32(address(leafMessageModule));
        vm.startPrank(address(leafMailbox));
    }

    function testGas_Deposit() public {
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.DEPOSIT, abi.encode(0, abi.encode(address(leafGauge), payload)));

        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_deposit");
    }

    function testGas_Withdraw() public {
        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory payload = abi.encode(amount, tokenId);
        bytes memory message = abi.encode(Commands.WITHDRAW, abi.encode(0, abi.encode(address(leafGauge), payload)));

        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({_payload: payload});
        leafIVR._deposit({_payload: payload});
        vm.stopPrank();

        vm.startPrank(address(leafMailbox));
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_withdraw");
    }

    function testGas_GetIncentives() public {
        uint256 tokenId = 1;
        bytes memory depositPayload = abi.encode(TOKEN_1, tokenId);
        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafIVR._deposit({_payload: depositPayload});
        vm.stopPrank();

        skipToNextEpoch(1);

        address[] memory tokens = new address[](5);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        tokens[2] = address(weth);
        tokens[3] = address(tokenA);
        tokens[4] = address(tokenB);
        bytes memory payload = abi.encode(users.alice, tokenId, tokens);
        bytes memory message = abi.encode(Commands.GET_INCENTIVES, abi.encode(address(leafGauge), payload));

        vm.startPrank(address(leafMailbox));
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_getIncentives");
    }

    function testGas_GetFees() public {
        uint256 tokenId = 1;
        bytes memory depositPayload = abi.encode(TOKEN_1, tokenId);
        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({_payload: depositPayload});
        vm.stopPrank();

        skipToNextEpoch(1);

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        bytes memory payload = abi.encode(users.alice, tokenId, tokens);
        bytes memory message = abi.encode(Commands.GET_FEES, abi.encode(address(leafGauge), payload));

        vm.startPrank(address(leafMailbox));
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_getFees");
    }

    function testGas_CreateGauge() public {
        /// @dev Disable snapshot checks for this test
        check = false;

        address pool = Clones.predictDeterministicAddress({
            deployer: address(leafPoolFactory),
            implementation: leafPoolFactory.implementation(),
            salt: keccak256(abi.encodePacked(address(token0), address(token1), true))
        });
        /// @dev Pool will be created during gauge creation
        assertFalse(leafPoolFactory.isPool(pool));

        uint24 _poolParam = 1;
        bytes memory payload = abi.encode(
            address(leafVotingRewardsFactory), address(leafGaugeFactory), address(token0), address(token1), _poolParam
        );
        bytes memory message = abi.encode(Commands.CREATE_GAUGE, abi.encode(address(leafPoolFactory), payload));
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_createGauge");
    }

    function testGas_NotifyRewardAmount() public {
        uint256 amount = TOKEN_1 * 1000;
        bytes memory payload = abi.encode(address(leafGauge), amount);
        bytes memory message = abi.encode(Commands.NOTIFY, payload);

        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_notifyRewardAmount");
    }

    function testGas_NotifyRewardWithoutClaim() public {
        uint256 amount = TOKEN_1 * 1000;
        bytes memory payload = abi.encode(address(leafGauge), amount);
        bytes memory message = abi.encode(Commands.NOTIFY_WITHOUT_CLAIM, payload);

        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_notifyRewardWithoutClaim");
    }

    function testGas_KillGauge() public {
        bytes memory payload = abi.encode(address(leafGauge));
        bytes memory message = abi.encode(Commands.KILL_GAUGE, payload);

        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_killGauge");
    }

    function testGas_ReviveGauge() public {
        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafVoter.killGauge(address(leafGauge));

        bytes memory payload = abi.encode(address(leafGauge));
        bytes memory message = abi.encode(Commands.REVIVE_GAUGE, payload);

        vm.startPrank(address(leafMailbox));
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_reviveGauge");
    }
}
