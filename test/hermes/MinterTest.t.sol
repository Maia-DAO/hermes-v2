// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import {BurntHermes} from "@hermes/BurntHermes.sol";
import {IBaseV2Minter, BaseV2Minter, FlywheelGaugeRewards} from "@hermes/minters/BaseV2Minter.sol";
import {HERMES} from "@hermes/tokens/HERMES.sol";

contract BaseV2MinterTest is DSTestPlus {
    //////////////////////////////////////////////////////////////////
    //                          VARIABLES
    //////////////////////////////////////////////////////////////////
    BurntHermes bHermesToken;

    BaseV2Minter baseV2Minter;

    FlywheelGaugeRewards flywheelGaugeRewards;

    HERMES rewardToken;

    //////////////////////////////////////////////////////////////////
    //                          SET UP
    //////////////////////////////////////////////////////////////////

    function setUp() public {
        rewardToken = new HERMES(address(this));

        bHermesToken = new BurntHermes(rewardToken, address(this), address(this));

        baseV2Minter = new BaseV2Minter(address(bHermesToken), address(this), address(this));

        rewardToken.transferOwnership(address(baseV2Minter));

        flywheelGaugeRewards = new FlywheelGaugeRewards(address(rewardToken), bHermesToken.gaugeWeight(), baseV2Minter);

        hevm.warp(52 weeks);
    }

    //////////////////////////////////////////////////////////////////
    //                          TESTS
    //////////////////////////////////////////////////////////////////

    function testInitialize() public {
        assertEq(address(baseV2Minter.flywheelGaugeRewards()), address(0));
        assertEq(baseV2Minter.activePeriod(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(address(baseV2Minter.flywheelGaugeRewards()), address(flywheelGaugeRewards));
    }

    function testInitializeFail() public {
        hevm.expectRevert(IBaseV2Minter.NotInitializer.selector);
        hevm.prank(address(1));
        baseV2Minter.initialize(flywheelGaugeRewards);
    }

    function testSetDao(address newDao) public {
        assertEq(address(baseV2Minter.dao()), address(this));
        baseV2Minter.setDao(newDao);
        assertEq(address(baseV2Minter.dao()), newDao);
    }

    function testSetDaoShare(uint96 newDaoShare) public {
        newDaoShare %= 3001;
        assertEq(baseV2Minter.daoShare(), 1000);
        baseV2Minter.setDaoShare(newDaoShare);
        assertEq(baseV2Minter.daoShare(), newDaoShare);
    }

    function testSetDaoShareFail(uint96 newDaoShare) public {
        newDaoShare %= type(uint96).max - 3001;
        newDaoShare += 3001;
        hevm.expectRevert(IBaseV2Minter.DaoShareTooHigh.selector);
        baseV2Minter.setDaoShare(newDaoShare);
    }

    function testSetTailEmission(uint96 newTailEmission) public {
        newTailEmission %= 101;
        assertEq(baseV2Minter.tailEmission(), 20);
        baseV2Minter.setTailEmission(newTailEmission);
        assertEq(baseV2Minter.tailEmission(), newTailEmission);
    }

    function testSetTailEmissionFail(uint96 newTailEmission) public {
        newTailEmission %= type(uint96).max - 101;
        newTailEmission += 101;
        hevm.expectRevert(IBaseV2Minter.TailEmissionTooHigh.selector);
        baseV2Minter.setTailEmission(newTailEmission);
    }

    function testCirculatingSupply() public {
        assertEq(baseV2Minter.circulatingSupply(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.circulatingSupply(), 0);
        hevm.prank(address(baseV2Minter));
        rewardToken.mint(address(this), 10000);
        assertEq(baseV2Minter.circulatingSupply(), 10000);

        rewardToken.approve(address(bHermesToken), 5000);
        bHermesToken.deposit(5000, address(this));
        assertEq(baseV2Minter.circulatingSupply(), 5000);
    }

    function testWeeklyEmission() public {
        assertEq(baseV2Minter.weeklyEmission(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.weeklyEmission(), 0);
        hevm.prank(address(baseV2Minter));
        rewardToken.mint(address(this), 10000);
        assertEq(baseV2Minter.weeklyEmission(), (10000 * 20) / 10000);

        rewardToken.approve(address(bHermesToken), 5000);
        bHermesToken.deposit(5000, address(this));
        assertEq(baseV2Minter.weeklyEmission(), (5000 * 20) / 10000);
    }

    function testCalculateGrowth() public {
        hevm.prank(address(baseV2Minter));
        rewardToken.mint(address(this), 10000);
        assertEq(baseV2Minter.calculateGrowth(1 ether), 0);

        rewardToken.approve(address(bHermesToken), 5000);
        bHermesToken.deposit(5000, address(this));
        assertEq(baseV2Minter.calculateGrowth(1 ether), 1 ether / 2);

        rewardToken.approve(address(bHermesToken), 5000);
        bHermesToken.deposit(5000, address(this));
        assertEq(baseV2Minter.calculateGrowth(1 ether), 1 ether);
    }

    function testUpdatePeriod() public {
        hevm.prank(address(baseV2Minter));
        rewardToken.mint(address(this), 10000);
        rewardToken.approve(address(bHermesToken), 5000);
        bHermesToken.deposit(5000, address(this));

        assertEq(baseV2Minter.activePeriod(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.activePeriod(), block.timestamp);
        hevm.warp(block.timestamp + 1 weeks);

        hevm.expectEmit(true, true, true, true);
        emit Mint(10, 5000, 5, 1);

        baseV2Minter.updatePeriod();
        assertEq(baseV2Minter.activePeriod(), block.timestamp);

        assertEq(rewardToken.balanceOf(address(bHermesToken)), 5005);
        assertEq(rewardToken.balanceOf(address(this)), 5001);
    }

    function testUpdatePeriodMinterHasBalance() public {
        hevm.prank(address(baseV2Minter));
        rewardToken.mint(address(baseV2Minter), 5000);
        hevm.prank(address(baseV2Minter));
        rewardToken.mint(address(this), 5000);
        rewardToken.approve(address(bHermesToken), 5000);
        bHermesToken.deposit(5000, address(this));

        assertEq(baseV2Minter.activePeriod(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.activePeriod(), block.timestamp);
        hevm.warp(block.timestamp + 1 weeks);

        hevm.expectEmit(true, true, true, true);
        emit Mint(10, 5000, 5, 1);

        baseV2Minter.updatePeriod();
        assertEq(baseV2Minter.activePeriod(), block.timestamp);

        assertEq(rewardToken.balanceOf(address(bHermesToken)), 5005);
        assertEq(rewardToken.balanceOf(address(this)), 1);
    }

    function testUpdatePeriodFallback() public {
        hevm.prank(address(baseV2Minter));
        rewardToken.mint(address(this), 10000);
        rewardToken.approve(address(bHermesToken), 5000);
        bHermesToken.deposit(5000, address(this));

        assertEq(baseV2Minter.activePeriod(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.activePeriod(), block.timestamp);
        hevm.warp(block.timestamp + 1 weeks);

        hevm.expectEmit(true, true, true, true);
        emit Mint(10, 5000, 5, 1);

        (bool successful,) = address(baseV2Minter).call("");
        assertTrue(successful);

        assertEq(baseV2Minter.activePeriod(), block.timestamp);
        assertEq(rewardToken.balanceOf(address(bHermesToken)), 5005);
        assertEq(rewardToken.balanceOf(address(this)), 5001);
    }

    function testUpdatePeriodNoDao() public {
        baseV2Minter.setDao(address(0));

        hevm.prank(address(baseV2Minter));
        rewardToken.mint(address(this), 10000);
        rewardToken.approve(address(bHermesToken), 5000);
        bHermesToken.deposit(5000, address(this));

        assertEq(baseV2Minter.activePeriod(), 0);
        baseV2Minter.initialize(flywheelGaugeRewards);
        assertEq(baseV2Minter.activePeriod(), block.timestamp);
        hevm.warp(block.timestamp + 1 weeks);

        hevm.expectEmit(true, true, true, true);
        emit Mint(10, 5000, 5, 0);

        baseV2Minter.updatePeriod();
        assertEq(baseV2Minter.activePeriod(), block.timestamp);

        assertEq(rewardToken.balanceOf(address(bHermesToken)), 5005);
        assertEq(rewardToken.balanceOf(address(this)), 5000);
    }

    function testGetRewards() public {
        testUpdatePeriod();

        assertEq(rewardToken.balanceOf(address(flywheelGaugeRewards)), 0);

        hevm.prank(address(flywheelGaugeRewards));
        baseV2Minter.getRewards();

        assertEq(rewardToken.balanceOf(address(flywheelGaugeRewards)), 10);
    }

    function testGetRewardsFail() public {
        testUpdatePeriod();

        hevm.expectRevert(IBaseV2Minter.NotFlywheelGaugeRewards.selector);
        baseV2Minter.getRewards();
    }

    /// @notice Emitted when weekly emissions are minted.
    event Mint(uint256 indexed weekly, uint256 indexed circulatingSupply, uint256 indexed growth, uint256 daoShare);
}
