// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {MockBooster} from "../mocks/MockBooster.sol";
import "../mocks/MockRewardsStream.sol";

import {BurntHermes as bHERMES} from "@hermes/BurntHermes.sol";
import {IbHermesUnderlying} from "@hermes/interfaces/IbHermesUnderlying.sol";
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

    bHERMES burntHermes;

    function setUp() public {
        hermes = new MockERC20("test hermes", "TKN", 18);

        strategy = new MockERC20("test strategy", "TKN", 18);

        burntHermes = new bHERMES(hermes, address(this), address(this));

        rewards = new FlywheelGaugeRewards(address(hermes), burntHermes.gaugeWeight(), IBaseV2Minter(address(stream)));
    }

    function mintHelper(uint256 amount, address user) internal {
        hermes.mint(user, amount);
        hermes.approve(address(burntHermes), amount);
        burntHermes.previewDeposit(amount);
        burntHermes.deposit(amount, user);
    }

    function testClaimOutstanding(uint256 amount, address user) public {
        if (amount == 0) amount = 1;

        hevm.startPrank(user);
        mintHelper(amount, user);

        burntHermes.claimOutstanding();
        hevm.stopPrank();

        assertEq(burntHermes.balanceOf(user), amount);
        assertEq(burntHermes.gaugeWeight().balanceOf(user), amount);
        assertEq(burntHermes.gaugeBoost().balanceOf(user), amount);
        assertEq(burntHermes.governance().balanceOf(user), amount);
    }

    function testClaimMultipleInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        burntHermes.claimMultiple(amount);
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
        burntHermes.claimMultipleAmounts(weight, boost, governance);
    }

    function testClaimWeightInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        burntHermes.claimWeight(amount);
    }

    function testClaimBoostInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        burntHermes.claimBoost(amount);
    }

    function testClaimGovernanceInsufficientShares(uint256 amount) public {
        if (amount != 0) hevm.expectRevert(IUtilityManager.InsufficientShares.selector);
        burntHermes.claimGovernance(amount);
    }

    function testMint() public {
        uint256 amount = 100 ether;
        hermes.mint(address(this), 100 ether);
        hermes.approve(address(burntHermes), amount);
        burntHermes.mint(amount, address(1));
        assertEq(burntHermes.balanceOf(address(1)), amount);
        assertEq(burntHermes.gaugeWeight().balanceOf(address(burntHermes)), amount);
        assertEq(burntHermes.gaugeBoost().balanceOf(address(burntHermes)), amount);
        assertEq(burntHermes.governance().balanceOf(address(burntHermes)), amount);
    }

    function testTransfer() public {
        testMint();
        hevm.prank(address(1));
        burntHermes.transfer(address(2), 100 ether);
        assertEq(burntHermes.balanceOf(address(1)), 0);
        assertEq(burntHermes.balanceOf(address(2)), 100 ether);

        assertEq(burntHermes.gaugeWeight().balanceOf(address(1)), 0);
        assertEq(burntHermes.gaugeWeight().balanceOf(address(burntHermes)), 100 ether);

        assertEq(burntHermes.gaugeBoost().balanceOf(address(1)), 0);
        assertEq(burntHermes.gaugeBoost().balanceOf(address(burntHermes)), 100 ether);

        assertEq(burntHermes.governance().balanceOf(address(1)), 0);
        assertEq(burntHermes.governance().balanceOf(address(burntHermes)), 100 ether);
    }

    function testTransferFailed() public {
        testMint();
        hevm.prank(address(1));
        burntHermes.claimWeight(1);
        hevm.expectRevert(abi.encodeWithSignature("InsufficientUnderlying()"));
        burntHermes.transfer(address(2), 100 ether);
    }

    function testTransferAndClaimOutstanding(uint256 amount, address user) public {
        if (amount == 0) amount = 1;
        if (user == address(this)) user = address(1);

        hevm.startPrank(user);
        mintHelper(amount, user);
        burntHermes.transfer(address(this), amount);
        hevm.stopPrank();

        burntHermes.claimOutstanding();

        assertEq(burntHermes.balanceOf(address(this)), amount);
        assertEq(burntHermes.gaugeWeight().balanceOf(address(this)), amount);
        assertEq(burntHermes.gaugeBoost().balanceOf(address(this)), amount);
        assertEq(burntHermes.governance().balanceOf(address(this)), amount);
    }

    function testTransferNotEnoughWeight(uint256 amount, address user) public {
        if (amount == 0) amount = 1;
        if (user == address(this)) user = address(1);

        hevm.startPrank(user);
        mintHelper(amount, user);

        burntHermes.claimWeight(amount);

        hevm.expectRevert(bHERMES.InsufficientUnderlying.selector);
        burntHermes.transfer(address(this), amount);
        hevm.stopPrank();

        assertEq(burntHermes.balanceOf(user), amount);
        assertEq(burntHermes.gaugeWeight().balanceOf(user), amount);
    }

    function testTransferNotEnoughBoost(uint256 amount, address user) public {
        if (amount == 0) amount = 1;
        if (user == address(this)) user = address(1);

        hevm.startPrank(user);
        mintHelper(amount, user);

        burntHermes.claimBoost(amount);

        hevm.expectRevert(bHERMES.InsufficientUnderlying.selector);
        burntHermes.transfer(address(this), amount);
        hevm.stopPrank();

        assertEq(burntHermes.balanceOf(user), amount);
        assertEq(burntHermes.gaugeBoost().balanceOf(user), amount);
    }

    function testTransferNotEnoughGovernance(uint256 amount, address user) public {
        if (amount == 0) amount = 1;
        if (user == address(this)) user = address(1);

        hevm.startPrank(user);
        mintHelper(amount, user);

        burntHermes.claimGovernance(amount);

        hevm.expectRevert(bHERMES.InsufficientUnderlying.selector);
        burntHermes.transfer(address(this), amount);
        hevm.stopPrank();

        assertEq(burntHermes.balanceOf(user), amount);
        assertEq(burntHermes.governance().balanceOf(user), amount);
    }

    function testTransferNotEnoughUtilityTokens(uint256 amount, address user) public {
        if (amount == 0) amount = 1;
        if (user == address(this)) user = address(1);

        hevm.startPrank(user);
        mintHelper(amount, user);

        burntHermes.claimOutstanding();

        hevm.expectRevert(bHERMES.InsufficientUnderlying.selector);
        burntHermes.transfer(address(this), amount);
        hevm.stopPrank();

        assertEq(burntHermes.balanceOf(user), amount);
        assertEq(burntHermes.gaugeWeight().balanceOf(user), amount);
        assertEq(burntHermes.gaugeBoost().balanceOf(user), amount);
        assertEq(burntHermes.governance().balanceOf(user), amount);
    }

    function testTransferFromAndClaimOutstanding(uint256 amount, address user) public {
        if (amount == 0) amount = 1;
        if (user == address(this)) user = address(1);

        hevm.startPrank(user);
        mintHelper(amount, user);

        burntHermes.approve(address(this), amount);
        hevm.stopPrank();

        burntHermes.transferFrom(user, address(this), amount);

        burntHermes.claimOutstanding();

        assertEq(burntHermes.balanceOf(address(this)), amount);
        assertEq(burntHermes.gaugeWeight().balanceOf(address(this)), amount);
        assertEq(burntHermes.gaugeBoost().balanceOf(address(this)), amount);
        assertEq(burntHermes.governance().balanceOf(address(this)), amount);
    }

    function testTransferFromNotEnoughWeight(uint256 amount, address user) public {
        if (amount == 0) amount = 1;
        if (user == address(this)) user = address(1);

        hevm.startPrank(user);
        mintHelper(amount, user);

        burntHermes.claimWeight(amount);

        burntHermes.approve(address(this), amount);
        hevm.stopPrank();

        hevm.expectRevert(bHERMES.InsufficientUnderlying.selector);
        burntHermes.transferFrom(user, address(this), amount);

        assertEq(burntHermes.balanceOf(user), amount);
        assertEq(burntHermes.gaugeWeight().balanceOf(user), amount);
    }

    function testTransferFromNotEnoughBoost(uint256 amount, address user) public {
        if (amount == 0) amount = 1;
        if (user == address(this)) user = address(1);

        hevm.startPrank(user);
        mintHelper(amount, user);

        burntHermes.claimBoost(amount);

        burntHermes.approve(address(this), amount);
        hevm.stopPrank();

        hevm.expectRevert(bHERMES.InsufficientUnderlying.selector);
        burntHermes.transferFrom(user, address(this), amount);

        assertEq(burntHermes.balanceOf(user), amount);
        assertEq(burntHermes.gaugeBoost().balanceOf(user), amount);
    }

    function testTransferFromNotEnoughGovernance(uint256 amount, address user) public {
        if (amount == 0) amount = 1;
        if (user == address(this)) user = address(1);

        hevm.startPrank(user);
        mintHelper(amount, user);

        burntHermes.claimGovernance(amount);

        burntHermes.approve(address(this), amount);
        hevm.stopPrank();

        hevm.expectRevert(bHERMES.InsufficientUnderlying.selector);
        burntHermes.transferFrom(user, address(this), amount);

        assertEq(burntHermes.balanceOf(user), amount);
        assertEq(burntHermes.governance().balanceOf(user), amount);
    }

    function testTransferFromNotEnoughUtilityTokens(uint256 amount, address user) public {
        if (amount == 0) amount = 1;
        if (user == address(this)) user = address(1);

        hevm.startPrank(user);
        mintHelper(amount, user);

        burntHermes.claimOutstanding();

        burntHermes.approve(address(this), amount);
        hevm.stopPrank();

        hevm.expectRevert(bHERMES.InsufficientUnderlying.selector);
        burntHermes.transferFrom(user, address(this), amount);

        assertEq(burntHermes.balanceOf(user), amount);
        assertEq(burntHermes.gaugeWeight().balanceOf(user), amount);
        assertEq(burntHermes.gaugeBoost().balanceOf(user), amount);
        assertEq(burntHermes.governance().balanceOf(user), amount);
    }

    function testBurnbHermesVotes(uint256 amount, address user) public {
        if (amount == 0) amount = 1;
        if (user == address(this)) user = address(1);

        hevm.startPrank(user);
        mintHelper(amount, user);

        burntHermes.claimOutstanding();
        hevm.stopPrank();

        hevm.startPrank(address(burntHermes));
        burntHermes.governance().burn(user, amount);
        hevm.stopPrank();

        assertEq(burntHermes.balanceOf(user), amount);
        assertEq(burntHermes.gaugeWeight().balanceOf(user), amount);
        assertEq(burntHermes.gaugeBoost().balanceOf(user), amount);
        assertEq(burntHermes.governance().balanceOf(user), 0);
    }
}
