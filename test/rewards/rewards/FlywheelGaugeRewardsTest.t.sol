// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockERC20Gauges} from "../../erc-20/mocks/MockERC20Gauges.t.sol";
import {MockRewardsStream} from "../mocks/MockRewardsStream.sol";
import {MockBaseV2Gauge, ERC20} from "../../gauges/mocks/MockBaseV2Gauge.sol";

import {FlywheelBoosterGaugeWeight} from "@rewards/booster/FlywheelBoosterGaugeWeight.sol";
import "@rewards/rewards/FlywheelGaugeRewards.sol";

contract FlywheelGaugeRewardsTest is DSTestPlus {
    FlywheelGaugeRewards rewards;

    FlywheelBoosterGaugeWeight flywheelBooster;

    MockERC20 public rewardToken;

    MockERC20Gauges gaugeToken;

    MockRewardsStream rewardsStream;

    address gauge1;
    address gauge2;
    address gauge3;
    address gauge4;

    function setUp() public {
        hevm.warp(1 weeks); // skip to cycle 1

        rewardToken = new MockERC20("test token", "TKN", 18);

        rewardsStream = new MockRewardsStream(rewardToken, 100e18);
        rewardToken.mint(address(rewardsStream), 100e25);

        flywheelBooster = new FlywheelBoosterGaugeWeight();

        gaugeToken = new MockERC20Gauges(address(this), address(flywheelBooster));
        gaugeToken.setMaxGauges(10);
        gaugeToken.mint(address(this), 100e18);
        gaugeToken.setMaxDelegates(1);
        gaugeToken.delegate(address(this));
        flywheelBooster.transferOwnership(address(gaugeToken));

        rewards = new FlywheelGaugeRewards(
            address(rewardToken),
            gaugeToken,
            IBaseV2Minter(address(rewardsStream))
        );

        hevm.mockCall(address(0), abi.encodeWithSignature("rewardToken()"), abi.encode(ERC20(address(0xDEAD))));
        hevm.mockCall(address(this), abi.encodeWithSignature("bribesFactory()"), abi.encode(address(this)));
        hevm.mockCall(address(0), abi.encodeWithSignature("gaugeToken()"), abi.encode(ERC20Gauges(address(0xBEEF))));
        hevm.mockCall(
            address(this), abi.encodeWithSignature("bHermesBoostToken()"), abi.encode(ERC20Gauges(address(0xBABE)))
        );
        hevm.mockCall(address(rewardsStream), abi.encodeWithSignature("updatePeriod()"), abi.encode(0));

        gauge1 = address(0xCAFE);
        gauge2 = address(0xBEEF);
        gauge3 = address(0xDEAD);
        gauge4 = address(0xABBA);
    }

    function testGetRewardsUninitialized() public {
        require(rewards.getAccruedRewards() == 0);
    }

    function testQueueWithoutGaugesBeforeCycle() public {
        hevm.expectRevert(abi.encodeWithSignature("CycleError()"));
        rewards.queueRewardsForCycle();
    }

    function testQueueWithoutGaugesNoGauges() public {
        hevm.warp(block.timestamp + 1 weeks);
        hevm.expectRevert(abi.encodeWithSignature("EmptyGaugesError()"));
        rewards.queueRewardsForCycle();
    }

    function testQueue() public {
        gaugeToken.addGauge(gauge1);
        gaugeToken.addGauge(gauge2);
        gaugeToken.incrementGauge(gauge1, 1e18);
        gaugeToken.incrementGauge(gauge2, 3e18);

        hevm.warp(block.timestamp + 1 weeks);

        rewards.queueRewardsForCycle();

        (uint112 prior1, uint112 stored1, uint32 cycle1) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior1 == 0);
        require(stored1 == 25e18);
        require(cycle1 == 2 weeks);

        (uint112 prior2, uint112 stored2, uint32 cycle2) = rewards.gaugeQueuedRewards(ERC20(gauge2));
        require(prior2 == 0);
        require(stored2 == 75e18);
        require(cycle2 == 2 weeks);

        require(rewards.gaugeCycle() == 2 weeks);
    }

    function testQueueSkipCycle() public {
        gaugeToken.addGauge(gauge1);
        gaugeToken.incrementGauge(gauge1, 1e18);

        hevm.warp(block.timestamp + 2 weeks);

        rewards.queueRewardsForCycle();

        (uint112 prior, uint112 stored, uint32 cycle) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior == 0);
        require(stored == 100e18);
        require(cycle == 3 weeks);

        require(rewards.gaugeCycle() == 3 weeks);
    }

    function testQueueTwoCycles() public {
        testQueue();
        gaugeToken.decrementGauge(gauge2, 2e18);

        hevm.warp(block.timestamp + 1 weeks);

        rewards.queueRewardsForCycle();

        (uint112 prior1, uint112 stored1, uint32 cycle1) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior1 == 25e18);
        require(stored1 == 50e18);
        require(cycle1 == 3 weeks);

        (uint112 prior2, uint112 stored2, uint32 cycle2) = rewards.gaugeQueuedRewards(ERC20(gauge2));
        require(prior2 == 75e18);
        require(stored2 == 50e18);
        require(cycle2 == 3 weeks);

        require(rewards.gaugeCycle() == 3 weeks);
    }

    function testGetRewards() public {
        testQueue();

        hevm.prank(gauge1);
        require(rewards.getAccruedRewards() == 25e18);
        (, uint112 stored,) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(stored == 0);
    }

    function testGetPriorRewards() public {
        testQueueTwoCycles();

        // accrue 100%
        hevm.warp(block.timestamp + 1 days);
        hevm.prank(gauge1);
        require(rewards.getAccruedRewards() == 75e18);
        (uint112 prior, uint112 stored,) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior == 0);
        require(stored == 0);
    }

    /*///////////////////////////////////////////////////////////////
                        FULL PAGINATION TESTS
    //////////////////////////////////////////////////////////////*/

    // The following tests all queue using a single pagination loop. They are intended to test the equivalence between the pagination operation and queueing when the numGauges is small enough to do all at once.

    function testQueueFullPagination() public {
        gaugeToken.addGauge(gauge1);
        gaugeToken.addGauge(gauge2);
        gaugeToken.incrementGauge(gauge1, 1e18);
        gaugeToken.incrementGauge(gauge2, 3e18);

        hevm.warp(block.timestamp + 1 weeks);

        rewards.queueRewardsForCyclePaginated(5);

        (uint112 prior1, uint112 stored1, uint32 cycle1) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior1 == 0);
        require(stored1 == 25e18);
        require(cycle1 == 2 weeks);

        (uint112 prior2, uint112 stored2, uint32 cycle2) = rewards.gaugeQueuedRewards(ERC20(gauge2));
        require(prior2 == 0);
        require(stored2 == 75e18);
        require(cycle2 == 2 weeks);

        require(rewards.gaugeCycle() == 2 weeks);
    }

    function testQueueSkipCycleFullPagination() public {
        gaugeToken.addGauge(gauge1);
        gaugeToken.incrementGauge(gauge1, 1e18);

        hevm.warp(block.timestamp + 2 weeks);

        rewards.queueRewardsForCyclePaginated(5);

        (uint112 prior, uint112 stored, uint32 cycle) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior == 0);
        require(stored == 100e18);
        require(cycle == 3 weeks);

        require(rewards.gaugeCycle() == 3 weeks);
    }

    function testQueueTwoCyclesFullPagination() public {
        testQueueFullPagination();
        gaugeToken.decrementGauge(gauge2, 2e18);

        hevm.warp(block.timestamp + 1 weeks);

        rewards.queueRewardsForCyclePaginated(5);

        (uint112 prior1, uint112 stored1, uint32 cycle1) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior1 == 25e18);
        require(stored1 == 50e18);
        require(cycle1 == 3 weeks);

        (uint112 prior2, uint112 stored2, uint32 cycle2) = rewards.gaugeQueuedRewards(ERC20(gauge2));
        require(prior2 == 75e18);
        require(stored2 == 50e18);
        require(cycle2 == 3 weeks);

        require(rewards.gaugeCycle() == 3 weeks);
    }

    /*///////////////////////////////////////////////////////////////
                    PARTIAL PAGINATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testPagination() public {
        gaugeToken.addGauge(gauge1);
        gaugeToken.incrementGauge(gauge1, 1e18);

        gaugeToken.addGauge(gauge2);
        gaugeToken.incrementGauge(gauge2, 2e18);

        gaugeToken.addGauge(gauge3);
        gaugeToken.incrementGauge(gauge3, 3e18);

        gaugeToken.addGauge(gauge4);
        gaugeToken.incrementGauge(gauge4, 4e18);

        hevm.warp(block.timestamp + 1 weeks);

        require(rewards.gaugeCycle() == 1 weeks);

        rewards.queueRewardsForCyclePaginated(2);

        // pagination not complete, cycle not complete
        require(rewards.gaugeCycle() == 1 weeks);

        (uint112 prior1, uint112 stored1, uint32 cycle1) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior1 == 0);
        require(stored1 == 10e18);
        require(cycle1 == 2 weeks);

        (uint112 prior2, uint112 stored2, uint32 cycle2) = rewards.gaugeQueuedRewards(ERC20(gauge2));
        require(prior2 == 0);
        require(stored2 == 20e18);
        require(cycle2 == 2 weeks);

        (uint112 prior3, uint112 stored3, uint32 cycle3) = rewards.gaugeQueuedRewards(ERC20(gauge3));
        require(prior3 == 0);
        require(stored3 == 0);
        require(cycle3 == 0);

        (uint112 prior4, uint112 stored4, uint32 cycle4) = rewards.gaugeQueuedRewards(ERC20(gauge4));
        require(prior4 == 0);
        require(stored4 == 0);
        require(cycle4 == 0);

        rewards.queueRewardsForCyclePaginated(2);

        require(rewards.gaugeCycle() == 2 weeks);

        (prior1, stored1, cycle1) = rewards.gaugeQueuedRewards(ERC20(gauge1));
        require(prior1 == 0);
        require(stored1 == 10e18);
        require(cycle1 == 2 weeks);

        (prior2, stored2, cycle2) = rewards.gaugeQueuedRewards(ERC20(gauge2));
        require(prior2 == 0);
        require(stored2 == 20e18);
        require(cycle2 == 2 weeks);

        (prior3, stored3, cycle3) = rewards.gaugeQueuedRewards(ERC20(gauge3));
        require(prior3 == 0);
        require(stored3 == 30e18);
        require(cycle3 == 2 weeks);

        (prior4, stored4, cycle4) = rewards.gaugeQueuedRewards(ERC20(gauge4));
        require(prior4 == 0);
        require(stored4 == 40e18);
        require(cycle4 == 2 weeks);
    }

    function testIncompletePagination() public {
        testQueue();

        gaugeToken.addGauge(gauge3);
        gaugeToken.incrementGauge(gauge3, 2e18);

        gaugeToken.addGauge(gauge4);
        gaugeToken.incrementGauge(gauge4, 4e18);

        hevm.warp(block.timestamp + 1 weeks);

        require(rewards.gaugeCycle() == 2 weeks);

        rewards.queueRewardsForCyclePaginated(2);

        // pagination not complete, cycle not complete
        require(rewards.gaugeCycle() == 2 weeks);

        hevm.warp(block.timestamp + 1 weeks / 2);
        hevm.prank(gauge1);
        require(rewards.getAccruedRewards() == 25e18); // only previous round
        hevm.prank(gauge2);
        require(rewards.getAccruedRewards() == 75e18); // only previous round
        hevm.prank(gauge3);
        require(rewards.getAccruedRewards() == 0); // nothing because no previous round
        hevm.prank(gauge4);
        require(rewards.getAccruedRewards() == 0); // nothing because no previous round

        hevm.warp(block.timestamp + 1 weeks / 2);

        // should reset the pagination process without queueing the last one
        rewards.queueRewardsForCyclePaginated(2);

        // pagination still not complete, cycle not complete
        require(rewards.gaugeCycle() == 2 weeks);

        hevm.warp(block.timestamp + 1 weeks / 2);
        hevm.prank(gauge1);
        require(rewards.getAccruedRewards() == 0); // only previous round
        hevm.prank(gauge2);
        require(rewards.getAccruedRewards() == 0); // only previous round
        hevm.prank(gauge3);
        require(rewards.getAccruedRewards() == 0); // nothing because no previous round
        hevm.prank(gauge4);
        require(rewards.getAccruedRewards() == 0); // nothing because no previous round

        // should reset the pagination process without queueing the last one
        rewards.queueRewardsForCyclePaginated(2);

        // pagination complete, cycle complete
        require(rewards.gaugeCycle() == 4 weeks);

        hevm.warp(block.timestamp + 1 weeks / 2);
        hevm.prank(gauge1);
        require(rewards.getAccruedRewards() == 20e18); // only previous round
        hevm.prank(gauge2);
        require(rewards.getAccruedRewards() == 60e18); // only previous round
        hevm.prank(gauge3);
        require(rewards.getAccruedRewards() == 40e18); // nothing because no previous round
        hevm.prank(gauge4);
        require(rewards.getAccruedRewards() == 80e18); // nothing because no previous round
    }
}
