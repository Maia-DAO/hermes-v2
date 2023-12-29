// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {MockBooster} from "../mocks/MockBooster.sol";
import "../mocks/MockRewardsStream.sol";

import {BurntHermes as bHERMES} from "@hermes/BurntHermes.sol";
import {IUtilityManager} from "@hermes/interfaces/IUtilityManager.sol";

import "@rewards/base/FlywheelCore.sol";
import {FlywheelGaugeRewards, IBaseV2Minter} from "@rewards/rewards/FlywheelGaugeRewards.sol";

contract BurntHermesTest is DSTestPlus {
    FlywheelCore flywheel;
    FlywheelGaugeRewards rewards;
    MockRewardsStream stream;

    MockERC20 strategy;
    MockERC20 hermes;
    MockBooster booster;

    bHERMES BurntHermes;

    function setUp() public {
        hermes = new MockERC20("test hermes", "TKN", 18);

        strategy = new MockERC20("test strategy", "TKN", 18);

        BurntHermes = new bHERMES(hermes, address(this), address(this));

        rewards = new FlywheelGaugeRewards(address(hermes), BurntHermes.gaugeWeight(), IBaseV2Minter(address(stream)));
    }

    function mintHelper(uint256 amount, address user) internal {
        hermes.mint(user, amount);
        hermes.approve(address(BurntHermes), amount);
        BurntHermes.previewDeposit(amount);
        BurntHermes.deposit(amount, user);
    }

    function testClaimMultipleInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        BurntHermes.claimMultiple(amount);
    }

    function testClaimMultipleInsufficientShares(uint256 amount, address user) public {
        if (amount != 0 && user != address(this)) {
            hevm.startPrank(user);
            mintHelper(amount, user);
            hevm.stopPrank();
        }
        testClaimMultipleInsufficientShares(amount);
    }

    function testClaimMultipleInsufficientShares(uint256 amount, uint256 diff) public {
        diff %= type(uint256).max - 1;
        amount %= type(uint256).max - ++diff;
        if (amount != 0) {
            mintHelper(amount, address(this));
        }
        amount += diff;
        testClaimMultipleInsufficientShares(amount);
    }

    function testClaimMultipleAmountsInsufficientShares(uint256 weight, uint256 boost, uint256 governance) public {
        if (weight != 0 || boost != 0 || governance != 0) {
            hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        }
        BurntHermes.claimMultipleAmounts(weight, boost, governance);
    }

    function testClaimWeightInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        BurntHermes.claimWeight(amount);
    }

    function testClaimBoostInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        BurntHermes.claimBoost(amount);
    }

    function testClaimGovernanceInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        BurntHermes.claimGovernance(amount);
    }

    function testMint() public {
        uint256 amount = 100 ether;
        hermes.mint(address(this), 100 ether);
        hermes.approve(address(BurntHermes), amount);
        BurntHermes.mint(amount, address(1));
        assertEq(BurntHermes.balanceOf(address(1)), amount);
        assertEq(BurntHermes.gaugeWeight().balanceOf(address(BurntHermes)), amount);
        assertEq(BurntHermes.gaugeBoost().balanceOf(address(BurntHermes)), amount);
        assertEq(BurntHermes.governance().balanceOf(address(BurntHermes)), amount);
    }

    function testTransfer() public {
        testMint();
        hevm.prank(address(1));
        BurntHermes.transfer(address(2), 100 ether);
        assertEq(BurntHermes.balanceOf(address(1)), 0);
        assertEq(BurntHermes.balanceOf(address(2)), 100 ether);

        assertEq(BurntHermes.gaugeWeight().balanceOf(address(1)), 0);
        assertEq(BurntHermes.gaugeWeight().balanceOf(address(BurntHermes)), 100 ether);

        assertEq(BurntHermes.gaugeBoost().balanceOf(address(1)), 0);
        assertEq(BurntHermes.gaugeBoost().balanceOf(address(BurntHermes)), 100 ether);

        assertEq(BurntHermes.governance().balanceOf(address(1)), 0);
        assertEq(BurntHermes.governance().balanceOf(address(BurntHermes)), 100 ether);
    }

    function testTransferFailed() public {
        testMint();
        hevm.prank(address(1));
        BurntHermes.claimWeight(1);
        hevm.expectRevert(abi.encodeWithSignature("InsufficientUnderlying()"));
        BurntHermes.transfer(address(2), 100 ether);
    }
}
