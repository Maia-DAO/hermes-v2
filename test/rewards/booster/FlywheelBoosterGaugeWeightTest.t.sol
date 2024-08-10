// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {Ownable} from "solady/auth/Ownable.sol";

import {BaseV2Gauge} from "@gauges/BaseV2Gauge.sol";

import {
    bHermesGauges,
    FlywheelBoosterGaugeWeight,
    IFlywheelBooster
} from "@rewards/booster/FlywheelBoosterGaugeWeight.sol";
import {MultiRewardsDepot} from "@rewards/depots/MultiRewardsDepot.sol";
import {FlywheelCore, ERC20} from "@rewards/base/FlywheelCore.sol";

import {FlywheelBoosterGaugeWeightHandler} from "@test/utils/invariant/handlers/FlywheelBoosterGaugeWeightHandler.t.sol";

contract InvariantFlywheelBoosterGaugeWeight is Test {
    /*///////////////////////////////////////////////////////////////
                                STATE
    ///////////////////////////////////////////////////////////////*/

    address public handler;
    FlywheelBoosterGaugeWeightHandler public boosterHandler;

    // FlyWheel Booster Gauge Weight contract
    FlywheelBoosterGaugeWeight public booster;
    // bHermes Gauges contract
    bHermesGauges public gaugeToken;

    /*///////////////////////////////////////////////////////////////
                                SETUP
    ///////////////////////////////////////////////////////////////*/

    function setUpHandler() public virtual {
        handler = address(new FlywheelBoosterGaugeWeightHandler());
    }

    function setUp() public {
        // Deploy the booster contract
        // 1 week Flywheel Bribe Rewards period
        booster = new FlywheelBoosterGaugeWeight(address(this));

        // Deploy the bHermes Gauges contract
        // 1 week gauge weight voting period and 1 day grace period
        gaugeToken = new bHermesGauges(address(this), address(booster));
        // Set the max number of gauges to 5
        gaugeToken.setMaxGauges(5);
        // Set the max number of delegates to 1
        gaugeToken.setMaxDelegates(1);

        // Transfer ownership of the booster contract to the bHermes Gauges contract
        booster.transferOwnership(address(gaugeToken));
        // Transfer ownership of the bribes factory contract to the booster contract
        booster.bribesFactory().transferOwnership(address(gaugeToken));

        excludeContract(address(gaugeToken));
        excludeContract(address(booster));
        excludeContract(address(booster.bribesFactory()));

        setUpHandler();
        boosterHandler = FlywheelBoosterGaugeWeightHandler(handler);

        excludeContract(handler);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = FlywheelBoosterGaugeWeightHandler.optIn.selector;
        selectors[1] = FlywheelBoosterGaugeWeightHandler.optOut.selector;
        selectors[2] = FlywheelBoosterGaugeWeightHandler.incrementWeight.selector;
        selectors[3] = FlywheelBoosterGaugeWeightHandler.decrementWeight.selector;

        targetSelector(FuzzSelector({addr: handler, selectors: selectors}));

        // Setup Gauges and Flywheels
        address[] memory gauges = createGauges(2);
        address[] memory flywheels = createFlywheels(3);
        addGaugesToFlywheels(gauges, flywheels);
    }

    function createGauges(uint256 numGauges) internal returns (address[] memory gauges) {
        gauges = new address[](numGauges);

        for (uint256 i = 1; i <= numGauges; i++) {
            address newGauge = address(uint160(i));

            address newDepot = address(addGauge(newGauge));
            boosterHandler.addGauge(newGauge);
            gauges[i - 1] = newGauge;

            excludeContract(newGauge);
            excludeContract(newDepot);
            excludeSender(newGauge);
            excludeSender(newDepot);
        }
    }

    function createFlywheels(uint256 numFlywheels) internal returns (address[] memory flywheels) {
        flywheels = new address[](numFlywheels);

        for (uint256 i = 1; i <= numFlywheels; i++) {
            address newBribeToken = address(new MockERC20("Mock Token", "TKN", 18));

            address newFlywheel = address(booster.bribesFactory().createBribeFlywheel(newBribeToken));
            boosterHandler.addFlywheel(newFlywheel);
            flywheels[i - 1] = newFlywheel;

            excludeContract(newFlywheel);
            excludeContract(FlywheelCore(newFlywheel).flywheelRewards());
            excludeContract(newBribeToken);
            excludeSender(newFlywheel);
            excludeSender(FlywheelCore(newFlywheel).flywheelRewards());
            excludeSender(newBribeToken);
        }
    }

    function addGaugesToFlywheels(address[] memory gauges, address[] memory flywheels) internal {
        for (uint256 i = 0; i < gauges.length; i++) {
            for (uint256 j = 0; j < flywheels.length; j++) {
                booster.bribesFactory().addGaugetoFlywheel(gauges[i], FlywheelCore(flywheels[j]).rewardToken());
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                                HELPERS
    ///////////////////////////////////////////////////////////////*/

    function addGauge(address gauge) private returns (MultiRewardsDepot depot) {
        gaugeToken.addGauge(gauge);
        depot = new MultiRewardsDepot(address(booster.bribesFactory()));

        vm.mockCall(address(gauge), abi.encodeWithSignature("multiRewardsDepot()"), abi.encode(depot));
    }

    function optInMintAndIncrementWeight(uint256 amount)
        private
        returns (ERC20 gauge, FlywheelCore flywheel, address bribeRewards, MockERC20 token)
    {
        (gauge, flywheel) = test_OptIn();
        bribeRewards = address(flywheel.flywheelRewards());
        token = MockERC20(address(flywheel.rewardToken()));

        token.mint(address(BaseV2Gauge(address(gauge)).multiRewardsDepot()), amount);

        mintAndIncrementWeight(address(gauge), 1 ether);

        assertEq(token.balanceOf(address(bribeRewards)), 0);
    }

    function mintAndIncrementWeight(address gauge, uint112 amount) private {
        gaugeToken.mint(address(this), amount);
        gaugeToken.delegate(address(this));
        gaugeToken.incrementGauge(gauge, amount);
    }

    function dencrementWeight(address gauge, uint112 amount) private {
        gaugeToken.decrementGauge(gauge, amount);
    }

    /*///////////////////////////////////////////////////////////////
                               INVARIANTS
    ///////////////////////////////////////////////////////////////*/

    function assertBoostedTotalSupply(address gauge) external {
        address[] memory flywheels = boosterHandler.flywheels();

        uint256 gaugeTotalSupply = gaugeToken.getGaugeWeight(gauge);
        for (uint256 i; i < flywheels.length; i++) {
            uint256 expected = boosterHandler.ghost_gaugeFlyWheelBoostedTotalSuply(gauge, flywheels[i]);

            vm.prank(flywheels[i]);
            assertTrue(gaugeTotalSupply >= booster.boostedTotalSupply(ERC20(gauge)), "boostedTotalSupply");
            assertEq(booster.boostedTotalSupply(ERC20(gauge)), expected, "boostedTotalSupply");
        }
    }

    function assertBoostedBalanceOf(address user) external {
        address[] memory gauges = boosterHandler.gauges();
        address[] memory flywheels = boosterHandler.flywheels();
        for (uint256 i; i < gauges.length; i++) {
            uint256 gaugeAllocation = gaugeToken.getUserGaugeWeight(user, gauges[i]);
            for (uint256 j; j < flywheels.length; j++) {
                uint256 id = booster.userGaugeflywheelId(user, ERC20(gauges[i]), FlywheelCore(flywheels[j]));
                uint256 expected = id == 0 ? 0 : gaugeAllocation;

                vm.prank(flywheels[j]);
                assertEq(booster.boostedBalanceOf(ERC20(gauges[i]), user), expected, "boostedBalanceOf");
            }
        }
    }

    function assertUserGaugeFlywheels(address user) external {
        address[] memory gauges = boosterHandler.gauges();
        for (uint256 i; i < gauges.length; i++) {
            ERC20 gauge = ERC20(gauges[i]);
            uint256 length = booster.getUserGaugeFlywheels(user, gauge).length;
            for (uint256 j; j < length; j++) {
                FlywheelCore flywheel = booster.userGaugeFlywheels(user, gauge, j);
                assertEq(booster.userGaugeflywheelId(user, gauge, flywheel), j + 1, "userGaugeflywheelId");
            }
        }
    }

    function invariant_boostedTotalSupply() public {
        boosterHandler.forEachActor(this.assertBoostedTotalSupply);
    }

    function invariant_boostedBalanceOf() public {
        boosterHandler.forEachActor(this.assertBoostedBalanceOf);
    }

    function invariant_userGaugeFlywheels() public {
        boosterHandler.forEachActor(this.assertUserGaugeFlywheels);
    }

    function invariant_owner() public {
        assertEq(booster.owner(), address(gaugeToken));
    }

    function invariant_callSummary() public view {
        boosterHandler.callSummary();
    }

    /*///////////////////////////////////////////////////////////////
                            USER BRIBE OPT-IN
    ///////////////////////////////////////////////////////////////*/

    function _optIn(uint256 gaugeIndex, uint256 flywheelIndex) internal returns (ERC20 gauge, FlywheelCore flywheel) {
        gauge = ERC20(boosterHandler.gauges()[gaugeIndex]);
        flywheel = FlywheelCore(boosterHandler.flywheels()[flywheelIndex]);

        booster.optIn(gauge, flywheel);

        uint256 id = booster.userGaugeflywheelId(address(this), gauge, flywheel);
        assertGt(id, 0);
        assertEq(address(booster.userGaugeFlywheels(address(this), gauge, id - 1)), address(flywheel));
    }

    function test_OptIn() public returns (ERC20, FlywheelCore) {
        return _optIn(0, 0);
    }

    function test_OptIn_AlreadyOptedIn() public {
        (ERC20 gauge, FlywheelCore flywheel) = test_OptIn();

        vm.expectRevert(IFlywheelBooster.AlreadyOptedIn.selector);
        booster.optIn(gauge, flywheel);
    }

    function test_OptIn_InvalidGauge(ERC20 gauge) public {
        FlywheelCore flywheel = FlywheelCore(boosterHandler.flywheels()[0]);

        if (!boosterHandler.containsGauge(address(gauge))) {
            vm.expectRevert(IFlywheelBooster.InvalidGauge.selector);
        }
        booster.optIn(gauge, flywheel);
    }

    function test_OptIn_InvalidFlywheel(FlywheelCore flywheel) public {
        ERC20 gauge = ERC20(boosterHandler.gauges()[0]);

        if (!boosterHandler.containsFlywheel(address(flywheel))) {
            vm.expectRevert(IFlywheelBooster.InvalidFlywheel.selector);
        }
        booster.optIn(gauge, flywheel);
    }

    function test_OptIn_Claim() public {
        test_OptIn_Claim(100 ether);
    }

    function test_OptIn_Increment(uint112 amount) public {
        if (amount == 0) amount = 1;

        ERC20 gauge = ERC20(boosterHandler.gauges()[0]);
        FlywheelCore flywheel = FlywheelCore(boosterHandler.flywheels()[0]);

        mintAndIncrementWeight(address(gauge), amount);

        vm.startPrank(address(flywheel));
        assertEq(booster.boostedTotalSupply(gauge), 0);
        assertEq(booster.boostedBalanceOf(gauge, address(this)), 0);
        vm.stopPrank();
        assertEq(gaugeToken.getGaugeWeight(address(gauge)), amount);
        assertEq(gaugeToken.getUserGaugeWeight(address(this), address(gauge)), amount);

        test_OptIn();

        vm.startPrank(address(flywheel));
        assertEq(booster.boostedTotalSupply(gauge), amount);
        assertEq(booster.boostedBalanceOf(gauge, address(this)), amount);
        vm.stopPrank();
        assertEq(gaugeToken.getGaugeWeight(address(gauge)), amount);
        assertEq(gaugeToken.getUserGaugeWeight(address(this), address(gauge)), amount);
    }

    function test_OptIn_Increment_Decrement(uint112 amount) public {
        if (amount == 0) amount = 1;

        ERC20 gauge = ERC20(boosterHandler.gauges()[0]);
        FlywheelCore flywheel = FlywheelCore(boosterHandler.flywheels()[0]);

        mintAndIncrementWeight(address(gauge), amount);

        vm.startPrank(address(flywheel));
        assertEq(booster.boostedTotalSupply(gauge), 0);
        assertEq(booster.boostedBalanceOf(gauge, address(this)), 0);
        vm.stopPrank();
        assertEq(gaugeToken.getGaugeWeight(address(gauge)), amount);
        assertEq(gaugeToken.getUserGaugeWeight(address(this), address(gauge)), amount);

        test_OptIn();

        vm.startPrank(address(flywheel));
        assertEq(booster.boostedTotalSupply(gauge), amount);
        assertEq(booster.boostedBalanceOf(gauge, address(this)), amount);
        vm.stopPrank();
        assertEq(gaugeToken.getGaugeWeight(address(gauge)), amount);
        assertEq(gaugeToken.getUserGaugeWeight(address(this), address(gauge)), amount);

        dencrementWeight(address(gauge), amount);

        vm.startPrank(address(flywheel));
        assertEq(booster.boostedTotalSupply(gauge), 0);
        assertEq(booster.boostedBalanceOf(gauge, address(this)), 0);
        vm.stopPrank();
        assertEq(gaugeToken.getGaugeWeight(address(gauge)), 0);
        assertEq(gaugeToken.getUserGaugeWeight(address(this), address(gauge)), 0);
    }

    function test_OptIn_Claim(uint256 amount) public {
        amount %= type(uint128).max;
        (ERC20 gauge, FlywheelCore flywheel, address bribeRewards, MockERC20 token) =
            optInMintAndIncrementWeight(amount);

        vm.warp(block.timestamp + 1 weeks); // skip to first cycle
        flywheel.accrue(gauge, address(this));

        assertEq(token.balanceOf(address(bribeRewards)), amount);
        assertEq(token.balanceOf(address(this)), 0);

        flywheel.claimRewards(address(this));

        assertEq(token.balanceOf(address(bribeRewards)), 0);
        assertEq(token.balanceOf(address(this)), amount);
    }

    /*///////////////////////////////////////////////////////////////
                            USER BRIBE OPT-OUT
    ///////////////////////////////////////////////////////////////*/

    function test_OptIn_OptOut() public {
        test_OptIn_OptOut(100 ether);
    }

    function test_OptIn_OptOut(uint256 amount) public {
        amount %= type(uint128).max;
        (ERC20 gauge, FlywheelCore flywheel, address bribeRewards, MockERC20 token) =
            optInMintAndIncrementWeight(amount);

        assertEq(booster.userGaugeflywheelId(address(this), gauge, flywheel), 1);
        booster.optOut(gauge, flywheel, true);
        assertEq(booster.userGaugeflywheelId(address(this), gauge, flywheel), 0);

        vm.warp(block.timestamp + 1 weeks); // skip to first cycle
        flywheel.accrue(ERC20(address(gauge)), address(this));

        assertEq(token.balanceOf(address(bribeRewards)), amount);
        assertEq(token.balanceOf(address(this)), 0);

        flywheel.claimRewards(address(this));

        assertEq(token.balanceOf(address(bribeRewards)), amount);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_OptOut() public {
        (ERC20 gauge, FlywheelCore flywheel) = test_OptIn();

        booster.optOut(gauge, flywheel, true);
        assertEq(booster.userGaugeflywheelId(address(this), gauge, flywheel), 0);
    }

    function test_OptIn_OptIn_OptOut() public {
        (ERC20 gauge1, FlywheelCore flywheel1) = _optIn(0, 0);
        (ERC20 gauge2, FlywheelCore flywheel2) = _optIn(0, 1);
        assertEq(booster.userGaugeflywheelId(address(this), gauge1, flywheel1), 1);
        assertEq(booster.userGaugeflywheelId(address(this), gauge2, flywheel2), 2);

        booster.optOut(gauge1, flywheel1, true);
        assertEq(booster.userGaugeflywheelId(address(this), gauge1, flywheel1), 0);
        assertEq(booster.userGaugeflywheelId(address(this), gauge2, flywheel2), 1);
    }

    function test_OptOut_NotOptedIn(ERC20 gauge, FlywheelCore flywheel) public {
        vm.expectRevert(IFlywheelBooster.NotOptedIn.selector);
        booster.optOut(gauge, flywheel, true);
    }

    function test_OptOut_NotOptedInToStrategy(ERC20 newGauge) public {
        (ERC20 gauge, FlywheelCore flywheel) = test_OptIn();

        if (gauge != newGauge) vm.expectRevert(IFlywheelBooster.NotOptedIn.selector);
        booster.optOut(newGauge, flywheel, true);
    }

    function test_OptOut_NotOptedInToFlywheel(FlywheelCore newFlywheel) public {
        (ERC20 gauge, FlywheelCore flywheel) = test_OptIn();

        if (flywheel != newFlywheel) vm.expectRevert(IFlywheelBooster.NotOptedIn.selector);
        booster.optOut(gauge, newFlywheel, true);
    }

    function test_OptIn_OptOut_Increment(uint112 amount) public {
        if (amount == 0) amount = 1;

        (ERC20 gauge, FlywheelCore flywheel) = test_OptIn();

        mintAndIncrementWeight(address(gauge), amount);

        vm.startPrank(address(flywheel));
        assertEq(booster.boostedTotalSupply(gauge), amount);
        assertEq(booster.boostedBalanceOf(gauge, address(this)), amount);
        vm.stopPrank();
        assertEq(gaugeToken.getGaugeWeight(address(gauge)), amount);
        assertEq(gaugeToken.getUserGaugeWeight(address(this), address(gauge)), amount);

        booster.optOut(gauge, flywheel, true);

        vm.startPrank(address(flywheel));
        assertEq(booster.boostedTotalSupply(gauge), 0);
        assertEq(booster.boostedBalanceOf(gauge, address(this)), 0);
        vm.stopPrank();
        assertEq(gaugeToken.getGaugeWeight(address(gauge)), amount);
        assertEq(gaugeToken.getUserGaugeWeight(address(this), address(gauge)), amount);
    }

    /*///////////////////////////////////////////////////////////////
                       bHERMES GAUGE WEIGHT ACCRUAL
    ///////////////////////////////////////////////////////////////*/

    function test_accrueBribesPositiveDelta_Unauthorized() public {
        ERC20 gauge = ERC20(boosterHandler.gauges()[0]);
        vm.expectRevert(Ownable.Unauthorized.selector);
        booster.accrueBribesPositiveDelta(address(this), gauge, 0);
    }

    function test_accrueBribesNegativeDelta_Unauthorized() public {
        ERC20 gauge = ERC20(boosterHandler.gauges()[0]);
        vm.expectRevert(Ownable.Unauthorized.selector);
        booster.accrueBribesNegativeDelta(address(this), gauge, 0);
    }
}
