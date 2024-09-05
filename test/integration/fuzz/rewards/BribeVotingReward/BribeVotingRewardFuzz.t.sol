// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.19 <0.9.0;

import "test/BaseForkFixture.sol";
import "src/interfaces/external/IVoter.sol";

contract BribeVotingRewardFuzzTest is BaseForkFixture {
    uint256 votePower1 = MAX_TOKENS;
    uint256 votePower2 = MAX_TOKENS / 2;
    uint256 amount = TOKEN_1 * 1000;
    uint256 amount2 = TOKEN_1 * 2000;

    function setUp() public virtual override {
        super.setUp();
        vm.selectFork({forkId: leafId});

        skipToNextEpoch(0);
        //2 users deposit into leafivr
        _deposit(users.alice, votePower1);
        _deposit(users.bob, votePower2);
    }

    function test_InitialState() public view {
        assertEq(leafIVR.voter(), address(leafVoter));
        assertEq(leafIVR.authorized(), address(leafMessageBridge));
    }

    function _deposit(address _user, uint256 _amount) internal {
        uint256 tokenId = _user == users.alice ? 1 : 2;
        bytes memory data = abi.encode(_amount, tokenId);
        vm.prank(address(leafMessageModule));
        leafIVR._deposit(data);
    }

    function _getReward(address _user) internal {
        uint256 tokenId = _user == users.alice ? 1 : 2;
        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);

        bytes memory data = abi.encode(_user, tokenId, tokens);
        vm.prank(address(leafMessageModule));
        leafIVR.getReward(data);
    }

    function test_EarnedWithAlternatedNotifyAndGetReward(uint40 _ts1, uint40 _ts2, uint40 _ts3, uint40 _ts4) public {
        vm.assume(uint256(_ts1) + _ts2 + _ts3 + _ts4 <= WEEK * 2);

        bool stillCurrentEpoch;
        bool changedEpochNow;
        bool changedEpochOnLastIteration;
        uint256 expectedEarned1 = votePower1 * amount / (votePower1 + votePower2);
        uint256 expectedEarned2 = votePower2 * amount / (votePower1 + votePower2);
        uint256 expectedEarned11 = votePower1 * amount2 / (votePower1 + votePower2);
        uint256 expectedEarned12 = votePower2 * amount2 / (votePower1 + votePower2);

        // ts1
        skipTime(_ts1);

        assertEq(leafIVR.earned(address(weth), 1), 0);
        assertEq(leafIVR.earned(address(weth), 2), 0);
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.bob), 0);

        // notify 1
        deal(address(weth), address(this), amount);
        weth.approve(address(leafIVR), amount);
        leafIVR.notifyRewardAmount(address(weth), amount);
        uint256 notifyTimestamp = block.timestamp;

        assertEq(leafIVR.earned(address(weth), 1), 0);
        assertEq(leafIVR.earned(address(weth), 2), 0);
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.bob), 0);

        // ts2
        skipTime(_ts2);
        stillCurrentEpoch =
            VelodromeTimeLibrary.epochStart(notifyTimestamp) == VelodromeTimeLibrary.epochStart(block.timestamp);

        if (stillCurrentEpoch) {
            assertEq(leafIVR.earned(address(weth), 1), 0);
            assertEq(leafIVR.earned(address(weth), 2), 0);
        } else {
            assertEq(leafIVR.earned(address(weth), 1), expectedEarned1);
            assertEq(leafIVR.earned(address(weth), 2), expectedEarned2);
        }
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.bob), 0);

        // get reward
        _getReward(users.alice);

        if (stillCurrentEpoch) {
            assertEq(leafIVR.earned(address(weth), 2), 0);
            assertEq(weth.balanceOf(users.alice), 0);
        } else {
            assertEq(leafIVR.earned(address(weth), 2), expectedEarned2);
            assertEq(weth.balanceOf(users.alice), expectedEarned1);
        }
        assertEq(leafIVR.earned(address(weth), 1), 0);
        assertEq(weth.balanceOf(users.bob), 0);

        // ts3
        uint256 beforeTs = block.timestamp;
        skipTime(_ts3);
        changedEpochOnLastIteration = changedEpochNow;
        stillCurrentEpoch =
            VelodromeTimeLibrary.epochStart(notifyTimestamp) == VelodromeTimeLibrary.epochStart(block.timestamp);
        changedEpochNow = VelodromeTimeLibrary.epochStart(beforeTs) != VelodromeTimeLibrary.epochStart(block.timestamp);

        if (stillCurrentEpoch) {
            assertEq(leafIVR.earned(address(weth), 1), 0);
            assertEq(leafIVR.earned(address(weth), 2), 0);
            assertEq(weth.balanceOf(users.alice), 0);
        } else {
            if (changedEpochNow) {
                assertEq(leafIVR.earned(address(weth), 1), expectedEarned1);
                assertEq(leafIVR.earned(address(weth), 2), expectedEarned2);
                assertEq(weth.balanceOf(users.alice), 0);
            } else {
                assertEq(leafIVR.earned(address(weth), 1), 0);
                assertEq(leafIVR.earned(address(weth), 2), expectedEarned2);
                assertEq(weth.balanceOf(users.alice), expectedEarned1);
            }
        }
        assertEq(weth.balanceOf(users.bob), 0);

        // notify 2
        deal(address(weth), address(this), amount2);
        weth.approve(address(leafIVR), amount2);
        leafIVR.notifyRewardAmount(address(weth), amount2);

        if (stillCurrentEpoch) {
            assertEq(leafIVR.earned(address(weth), 1), 0);
            assertEq(leafIVR.earned(address(weth), 2), 0);
            assertEq(weth.balanceOf(users.alice), 0);
            assertEq(weth.balanceOf(users.bob), 0);
        } else {
            if (changedEpochNow) {
                assertEq(leafIVR.earned(address(weth), 1), expectedEarned1);
                assertEq(leafIVR.earned(address(weth), 2), expectedEarned2);
                assertEq(weth.balanceOf(users.alice), 0);
                assertEq(weth.balanceOf(users.bob), 0);
            } else {
                assertEq(leafIVR.earned(address(weth), 1), 0);
                assertEq(leafIVR.earned(address(weth), 2), expectedEarned2);
                assertEq(weth.balanceOf(users.alice), expectedEarned1);
                assertEq(weth.balanceOf(users.bob), 0);
            }
        }
        assertEq(weth.balanceOf(users.bob), 0);

        beforeTs = block.timestamp;
        // ts4
        skipTime(_ts4);
        changedEpochOnLastIteration = changedEpochNow;
        stillCurrentEpoch =
            VelodromeTimeLibrary.epochStart(notifyTimestamp) == VelodromeTimeLibrary.epochStart(block.timestamp);
        changedEpochNow = VelodromeTimeLibrary.epochStart(beforeTs) != VelodromeTimeLibrary.epochStart(block.timestamp);

        if (stillCurrentEpoch) {
            assertEq(leafIVR.earned(address(weth), 1), 0);
            assertEq(leafIVR.earned(address(weth), 2), 0);
            assertEq(weth.balanceOf(users.alice), 0);
            assertEq(weth.balanceOf(users.bob), 0);
        } else {
            if (changedEpochOnLastIteration) {
                assertEq(leafIVR.earned(address(weth), 1), expectedEarned1);
                assertEq(leafIVR.earned(address(weth), 2), expectedEarned2);
                assertEq(weth.balanceOf(users.alice), 0);
                assertEq(weth.balanceOf(users.bob), 0);
            } else {
                if (changedEpochNow) {
                    assertApproxEqAbs(leafIVR.earned(address(weth), 1), expectedEarned1 + expectedEarned11, 1);
                    assertApproxEqAbs(leafIVR.earned(address(weth), 2), expectedEarned2 + expectedEarned12, 1);
                    assertEq(weth.balanceOf(users.alice), 0);
                    assertEq(weth.balanceOf(users.bob), 0);
                } else {
                    assertEq(leafIVR.earned(address(weth), 1), 0);
                    assertEq(leafIVR.earned(address(weth), 2), expectedEarned2);
                    assertEq(weth.balanceOf(users.alice), expectedEarned1);
                    assertEq(weth.balanceOf(users.bob), 0);
                }
            }
        }

        // get reward x2
        _getReward(users.alice);
        _getReward(users.bob);

        if (stillCurrentEpoch) {
            assertEq(leafIVR.earned(address(weth), 1), 0);
            assertEq(leafIVR.earned(address(weth), 2), 0);
            assertEq(weth.balanceOf(users.alice), 0);
            assertEq(weth.balanceOf(users.bob), 0);
        } else {
            if (changedEpochOnLastIteration) {
                assertEq(leafIVR.earned(address(weth), 1), 0);
                assertEq(leafIVR.earned(address(weth), 2), 0);
                assertEq(weth.balanceOf(users.alice), expectedEarned1);
                assertEq(weth.balanceOf(users.bob), expectedEarned2);
            } else {
                if (changedEpochNow) {
                    assertEq(leafIVR.earned(address(weth), 1), 0);
                    assertEq(leafIVR.earned(address(weth), 2), 0);
                    assertApproxEqAbs(weth.balanceOf(users.alice), expectedEarned1 + expectedEarned11, 1);
                    assertApproxEqAbs(weth.balanceOf(users.bob), expectedEarned2 + expectedEarned12, 2);
                } else {
                    assertEq(leafIVR.earned(address(weth), 1), 0);
                    assertEq(leafIVR.earned(address(weth), 2), 0);
                    assertEq(weth.balanceOf(users.alice), expectedEarned1);
                    assertEq(weth.balanceOf(users.bob), expectedEarned2);
                }
            }
        }
    }

    function test_EarnedWithNotifyBeforeGetReward(uint40 _ts1, uint40 _ts2, uint40 _ts3, uint40 _ts4) public {
        vm.assume(uint256(_ts1) + _ts2 + _ts3 + _ts4 <= WEEK * 2);

        bool stillCurrentEpoch;
        bool changedEpochNow;
        bool changedEpochOnLastIteration;
        uint256 expectedEarned1 = votePower1 * amount / (votePower1 + votePower2);
        uint256 expectedEarned2 = votePower2 * amount / (votePower1 + votePower2);
        uint256 expectedEarned11 = votePower1 * amount2 / (votePower1 + votePower2);
        uint256 expectedEarned12 = votePower2 * amount2 / (votePower1 + votePower2);

        // ts1
        skipTime(_ts1);

        assertEq(leafIVR.earned(address(weth), 1), 0);
        assertEq(leafIVR.earned(address(weth), 2), 0);
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.bob), 0);

        // notify 1
        deal(address(weth), address(this), amount);
        weth.approve(address(leafIVR), amount);
        leafIVR.notifyRewardAmount(address(weth), amount);
        uint256 notifyTimestamp = block.timestamp;

        assertEq(leafIVR.earned(address(weth), 1), 0);
        assertEq(leafIVR.earned(address(weth), 2), 0);
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.bob), 0);

        // ts2
        skipTime(_ts2);
        stillCurrentEpoch =
            VelodromeTimeLibrary.epochStart(notifyTimestamp) == VelodromeTimeLibrary.epochStart(block.timestamp);
        changedEpochNow = !stillCurrentEpoch;

        if (stillCurrentEpoch) {
            assertEq(leafIVR.earned(address(weth), 1), 0);
            assertEq(leafIVR.earned(address(weth), 2), 0);
        } else {
            assertEq(leafIVR.earned(address(weth), 1), expectedEarned1);
            assertEq(leafIVR.earned(address(weth), 2), expectedEarned2);
        }
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.bob), 0);

        // notify 2
        deal(address(weth), address(this), amount2);
        weth.approve(address(leafIVR), amount2);
        leafIVR.notifyRewardAmount(address(weth), amount2);

        if (stillCurrentEpoch) {
            assertEq(leafIVR.earned(address(weth), 1), 0);
            assertEq(leafIVR.earned(address(weth), 2), 0);
        } else {
            assertEq(leafIVR.earned(address(weth), 1), expectedEarned1);
            assertEq(leafIVR.earned(address(weth), 2), expectedEarned2);
        }
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.bob), 0);

        uint256 beforeTs = block.timestamp;
        // ts3
        skipTime(_ts3);
        changedEpochOnLastIteration = changedEpochNow;
        stillCurrentEpoch =
            VelodromeTimeLibrary.epochStart(notifyTimestamp) == VelodromeTimeLibrary.epochStart(block.timestamp);
        changedEpochNow = VelodromeTimeLibrary.epochStart(beforeTs) != VelodromeTimeLibrary.epochStart(block.timestamp);

        if (stillCurrentEpoch) {
            assertEq(leafIVR.earned(address(weth), 1), 0);
            assertEq(leafIVR.earned(address(weth), 2), 0);
        } else {
            if (changedEpochNow) {
                assertApproxEqAbs(leafIVR.earned(address(weth), 1), expectedEarned1 + expectedEarned11, 1);
                assertApproxEqAbs(leafIVR.earned(address(weth), 2), expectedEarned2 + expectedEarned12, 1);
            } else {
                if (changedEpochOnLastIteration) {
                    assertEq(leafIVR.earned(address(weth), 1), expectedEarned1);
                    assertEq(leafIVR.earned(address(weth), 2), expectedEarned2);
                } else {
                    assertEq(leafIVR.earned(address(weth), 1), 0);
                    assertEq(leafIVR.earned(address(weth), 2), 0);
                }
            }
        }
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.bob), 0);

        // get reward x2
        _getReward(users.alice);
        _getReward(users.bob);

        if (stillCurrentEpoch) {
            assertEq(leafIVR.earned(address(weth), 1), 0);
            assertEq(leafIVR.earned(address(weth), 2), 0);
            assertEq(weth.balanceOf(users.alice), 0);
            assertEq(weth.balanceOf(users.bob), 0);
        } else {
            if (changedEpochNow) {
                assertEq(leafIVR.earned(address(weth), 1), 0);
                assertEq(leafIVR.earned(address(weth), 2), 0);
                assertApproxEqAbs(weth.balanceOf(users.alice), expectedEarned1 + expectedEarned11, 1);
                assertApproxEqAbs(weth.balanceOf(users.bob), expectedEarned2 + expectedEarned12, 1);
            } else {
                if (changedEpochOnLastIteration) {
                    assertEq(leafIVR.earned(address(weth), 1), 0);
                    assertEq(leafIVR.earned(address(weth), 2), 0);
                    assertEq(weth.balanceOf(users.alice), expectedEarned1);
                    assertEq(weth.balanceOf(users.bob), expectedEarned2);
                } else {
                    assertEq(leafIVR.earned(address(weth), 1), 0);
                    assertEq(leafIVR.earned(address(weth), 2), 0);
                    assertEq(weth.balanceOf(users.alice), 0);
                    assertEq(weth.balanceOf(users.bob), 0);
                }
            }
        }
    }
}
