// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockERC20Gauges} from "../../erc-20/mocks/MockERC20Gauges.t.sol";
import {MultiRewardsDepot} from "@rewards/depots/MultiRewardsDepot.sol";

import "@rewards/rewards/FlywheelBribeRewards.sol";

contract FlywheelBribeRewardsTest is DSTestPlus {
    FlywheelBribeRewards rewards;

    MockERC20 public rewardToken;

    MockERC20 public strategy;

    MockERC20Gauges gaugeToken;

    MultiRewardsDepot depot;

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);

        strategy = new MockERC20("test strategy", "TKN", 18);

        rewards = new FlywheelBribeRewards(FlywheelCore(address(this)));

        depot = new MultiRewardsDepot(address(this));

        depot.addAsset(address(rewards), address(rewardToken));

        rewards.setRewardsDepot(address(strategy), depot);
    }

    function testSetRewardsDepot(address newDepot) public {
        rewards.setRewardsDepot(address(strategy), RewardsDepot(newDepot));
        assertEq(address(rewards.rewardsDepots(ERC20(strategy))), newDepot);
    }

    function testGetAccruedRewardsUninitialized() public {
        assertEq(rewards.getAccruedRewards(strategy), 0);
        rewardToken.mint(address(depot), 100 ether);

        assertEq(rewards.getAccruedRewards(strategy), 0 ether, "Failed Accrue, timestamp < endCycle");
        assertEq(rewards.endCycles(strategy), 604800);
    }

    function testGetAccruedRewards() public {
        testGetAccruedRewardsUninitialized();

        hevm.warp(block.timestamp + 604800); // skip to next cycle

        assertEq(rewards.getAccruedRewards(strategy), 100 ether, "Failed Accrue");
        assertEq(rewards.endCycles(strategy), 1209600);
    }

    function testGetAccruedRewardsTwoCycles() public {
        testGetAccruedRewards();

        rewardToken.mint(address(depot), 100 ether);

        hevm.warp(block.timestamp + 604800); // skip to next cycle

        assertEq(rewards.getAccruedRewards(strategy), 100 ether, "Failed Accrue");
        assertEq(rewards.endCycles(strategy), 1814400);
    }

    function testGetAccruedRewardsBeforeTwoCycles() public {
        testGetAccruedRewards();

        rewardToken.mint(address(depot), 100 ether);

        assertEq(rewards.getAccruedRewards(strategy), 0 ether, "Failed Accrue, timestamp < endCycle");
        assertEq(rewards.endCycles(strategy), 1209600);

        hevm.warp(block.timestamp + 604800);

        assertEq(rewards.getAccruedRewards(strategy), 100 ether, "Failed Accrue");
        assertEq(rewards.endCycles(strategy), 1814400);
    }

    function parseAmount(uint192 amount) internal pure returns (uint192) {
        return (amount % type(uint192).max) + 1;
    }

    function testFuzzGetAccruedRewardsUninitialized(uint192 amount) public {
        amount = parseAmount(amount);

        assertEq(rewards.getAccruedRewards(strategy), 0);
        rewardToken.mint(address(depot), amount);
        assertEq(rewards.getAccruedRewards(strategy), 0);
        assertEq(rewards.endCycles(strategy), 604800);
    }

    function testFuzzGetAccruedRewards(uint192 amount) public {
        amount = parseAmount(amount);

        rewardToken.mint(address(depot), amount);

        assertEq(rewards.getAccruedRewards(strategy), 0, "Failed Accrue");

        hevm.warp(605800); // skip to cycle 2

        assertEq(rewards.getAccruedRewards(strategy), amount);

        assertEq(rewards.endCycles(strategy), 1209600);
    }
}
