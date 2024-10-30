// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "../../LeafHLMessageModule.t.sol";

contract HandleBenchmarksIntegrationConcreteTest is LeafHLMessageModuleTest {
    using stdStorage for StdStorage;

    uint32 public origin;
    bytes32 public sender;
    TestERC20 public tokenA;
    TestERC20 public tokenB;

    function setUp() public override {
        super.setUp();

        vm.selectFork({forkId: leafId});
        tokenA = new TestERC20("Test Token A", "TTA", 18);
        tokenB = new TestERC20("Test Token B", "TTB", 6); // mimic USDC

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

        origin = 10;
        uint256 amountToBridge = TOKEN_1 * 1000;
        setLimits({_rootBufferCap: amountToBridge * 2, _leafBufferCap: amountToBridge * 2});

        sender = TypeCasts.addressToBytes32(address(leafMessageModule));
        vm.startPrank(address(leafMailbox));
    }

    /// @dev Helper to seed rewards into reward contracts across multiple epochs
    function _seedRewards(address _rewards, address[] memory _tokens, uint256 _numEpochs, uint256 _amount) internal {
        uint256 length = _tokens.length;
        for (uint256 i = 0; i < length; i++) {
            deal(_tokens[i], address(leafGauge), _amount * _numEpochs);
        }
        vm.startPrank(address(leafGauge));
        for (uint256 i = 0; i < _numEpochs; i++) {
            for (uint256 j = 0; j < length; j++) {
                IERC20(_tokens[j]).approve(_rewards, _amount);
                IReward(_rewards).notifyRewardAmount(_tokens[j], _amount);
            }

            vm.warp(VelodromeTimeLibrary.epochNext(block.timestamp));
        }
        vm.stopPrank();
    }

    function testGas_Deposit() public {
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory message =
            abi.encodePacked(uint8(Commands.DEPOSIT), address(leafGauge), amount, tokenId, uint256(1000));

        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_deposit");
    }

    function testGas_Withdraw() public {
        stdstore.target(address(leafMessageModule)).sig("receivingNonce()").checked_write(1_000);

        uint256 amount = TOKEN_1 * 1000;
        uint256 tokenId = 1;
        bytes memory message =
            abi.encodePacked(uint8(Commands.WITHDRAW), address(leafGauge), amount, tokenId, uint256(1000));

        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({amount: amount, tokenId: tokenId});
        leafIVR._deposit({amount: amount, tokenId: tokenId});
        vm.stopPrank();

        vm.startPrank(address(leafMailbox));
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_withdraw");
    }

    function testGas_GetIncentives() public {
        uint256 tokenId = 1;
        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafIVR._deposit({amount: TOKEN_1, tokenId: tokenId});
        vm.stopPrank();

        // Using WETH, tokenA & tokenB as Incentive tokens
        address[] memory tokens = new address[](5);
        tokens[0] = address(weth);
        tokens[1] = address(token0);
        tokens[2] = address(token1);
        tokens[3] = address(tokenA);
        tokens[4] = address(tokenB);
        /// @dev Seed incentives across 10 Epochs
        _seedRewards({_rewards: address(leafIVR), _tokens: tokens, _numEpochs: 10, _amount: TOKEN_1});

        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_INCENTIVES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        vm.startPrank(address(leafMailbox));
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_getIncentives");
    }

    function testGas_GetFees() public {
        uint256 tokenId = 1;
        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafFVR._deposit({amount: TOKEN_1, tokenId: tokenId});
        vm.stopPrank();

        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        /// @dev Seed fees across 10 Epochs
        _seedRewards({_rewards: address(leafFVR), _tokens: tokens, _numEpochs: 10, _amount: TOKEN_1});

        bytes memory message = abi.encodePacked(
            uint8(Commands.GET_FEES), address(leafGauge), users.alice, tokenId, uint8(tokens.length), tokens
        );

        vm.startPrank(address(leafMailbox));
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_getFees");
    }

    function testGas_CreateGauge() public {
        address pool = Clones.predictDeterministicAddress({
            deployer: address(leafPoolFactory),
            implementation: leafPoolFactory.implementation(),
            salt: keccak256(abi.encodePacked(address(token0), address(token1), true))
        });
        /// @dev Pool will be created during gauge creation
        assertFalse(leafPoolFactory.isPool(pool));

        uint24 _poolParam = 1;
        bytes memory message = abi.encodePacked(
            uint8(Commands.CREATE_GAUGE),
            address(leafPoolFactory),
            address(leafVotingRewardsFactory),
            address(leafGaugeFactory),
            address(token0),
            address(token1),
            _poolParam
        );
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_createGauge");
    }

    function testGas_NotifyRewardAmount() public {
        uint256 amount = TOKEN_1 * 1000;
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY), address(leafGauge), amount);

        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_notifyRewardAmount");
    }

    function testGas_NotifyRewardWithoutClaim() public {
        uint256 amount = TOKEN_1 * 1000;
        bytes memory message = abi.encodePacked(uint8(Commands.NOTIFY_WITHOUT_CLAIM), address(leafGauge), amount);

        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_notifyRewardWithoutClaim");
    }

    function testGas_KillGauge() public {
        bytes memory message = abi.encodePacked(uint8(Commands.KILL_GAUGE), address(leafGauge));

        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_killGauge");
    }

    function testGas_ReviveGauge() public {
        vm.stopPrank();
        vm.startPrank(address(leafMessageModule));
        leafVoter.killGauge(address(leafGauge));

        bytes memory message = abi.encodePacked(uint8(Commands.REVIVE_GAUGE), address(leafGauge));

        vm.startPrank(address(leafMailbox));
        leafMessageModule.handle({_origin: origin, _sender: sender, _message: message});
        snapLastCall("LeafHLMessageModule_handle_reviveGauge");
    }
}
