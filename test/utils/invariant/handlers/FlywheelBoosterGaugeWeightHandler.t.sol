// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.13;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {BaseV2Gauge} from "@gauges/BaseV2Gauge.sol";

import {
    bHermesGauges,
    FlywheelBoosterGaugeWeight,
    IFlywheelBooster
} from "@rewards/booster/FlywheelBoosterGaugeWeight.sol";
import {FlywheelCore, ERC20} from "@rewards/FlywheelCoreStrategy.sol";

import {InvariantFlywheelBoosterGaugeWeight} from "@test/rewards/booster/FlywheelBoosterGaugeWeightTest.t.sol";

import {AddressSet, LibAddressSet} from "../helpers/AddressSet.sol";

contract FlywheelBoosterGaugeWeightHandler is CommonBase, StdCheats, StdUtils {
    using LibAddressSet for AddressSet;
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;

    address public owner = address(this);

    uint256 public ghost_incrementWeightSum;
    uint256 public ghost_decrementWeightSum;

    uint256 public ghost_zeroOptIn;
    uint256 public ghost_zeroOptOut;
    uint256 public ghost_zeroIncrementWeight;
    uint256 public ghost_zeroDecrementWeight;

    mapping(address => uint256) public ghost_gaugeIncrementWeightSum;
    mapping(address => uint256) public ghost_gaugeDecrementWeightSum;

    mapping(address => mapping(address => uint256)) public ghost_gaugeFlyWheelIncrementWeightSum;
    mapping(address => mapping(address => uint256)) public ghost_gaugeFlyWheelDecrementWeightSum;

    mapping(address => mapping(address => uint256)) public ghost_gaugeFlyWheelBoostedTotalSuply;

    mapping(bytes32 => uint256) public calls;

    AddressSet internal _actors;
    AddressSet internal _gauges;
    AddressSet internal _flywheels;

    FlywheelBoosterGaugeWeight public booster;

    address internal currentActor;
    address internal currentGauge;
    address internal currentFlywheel;

    uint256 constant MAX_DEPOSIT = type(uint96).max;

    uint256 constant MAX_ADDRESS_SET = 3;

    InvariantFlywheelBoosterGaugeWeight internal invariantBoosterTest;
    bHermesGauges internal gaugeToken;

    modifier advanceOneEpoch(bool skip) {
        if (skip) vm.warp(block.timestamp + 1 weeks);
        _;
    }

    modifier createActor(uint256 actorIndexSeed) {
        if (_actors.addrs.length < MAX_ADDRESS_SET) {
            currentActor = msg.sender;
            _actors.add(msg.sender);
        } else {
            currentActor = _actors.rand(actorIndexSeed);
        }
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = _actors.rand(actorIndexSeed);
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    modifier useGauge(uint256 gaugeIndexSeed) {
        currentGauge = _gauges.rand(gaugeIndexSeed);
        _;
    }

    modifier useFlywheel(uint256 flywheelIndexSeed) {
        currentFlywheel = _flywheels.rand(flywheelIndexSeed);
        _;
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    constructor() {
        invariantBoosterTest = InvariantFlywheelBoosterGaugeWeight(msg.sender);
        booster = invariantBoosterTest.booster();
        gaugeToken = bHermesGauges(booster.owner());
    }

    function addGauge(address gauge) public {
        _gauges.add(gauge);
    }

    function addFlywheel(address gauge) public {
        _flywheels.add(gauge);
    }

    function mintGaugeToken(uint256 amount) public {
        vm.stopPrank();
        vm.prank(address(invariantBoosterTest));
        gaugeToken.mint(currentActor, amount);
        vm.startPrank(currentActor);
    }

    function incrementGauge(uint112 amount) internal virtual {
        if (amount == 0) {
            ghost_zeroIncrementWeight++;
            return;
        }

        mintGaugeToken(amount);
        gaugeToken.incrementDelegation(currentActor, amount);
        gaugeToken.incrementGauge(currentGauge, amount);

        ghost_incrementWeightSum += amount;
        ghost_gaugeIncrementWeightSum[currentGauge] += amount;

        uint256 length = booster.getUserGaugeFlywheels(currentActor, ERC20(currentGauge)).length;
        for (uint256 j; j < length; j++) {
            address flywheel = address(booster.userGaugeFlywheels(currentActor, ERC20(currentGauge), j));
            ghost_gaugeFlyWheelIncrementWeightSum[currentGauge][flywheel] += amount;
            ghost_gaugeFlyWheelBoostedTotalSuply[currentGauge][flywheel] += amount;
        }
    }

    function decrementGauge(uint112 amount) internal virtual {
        uint112 userGaugeWeight = gaugeToken.getUserGaugeWeight(currentActor, currentGauge);
        if (amount == 0 || userGaugeWeight == 0) {
            ghost_zeroDecrementWeight++;
            return;
        }

        if (amount > userGaugeWeight) {
            amount = userGaugeWeight;
        }
        gaugeToken.decrementGauge(currentGauge, amount);

        ghost_decrementWeightSum += amount;
        ghost_gaugeDecrementWeightSum[currentGauge] += amount;

        uint256 length = booster.getUserGaugeFlywheels(currentActor, ERC20(currentGauge)).length;
        for (uint256 j; j < length; j++) {
            address flywheel = address(booster.userGaugeFlywheels(currentActor, ERC20(currentGauge), j));
            ghost_gaugeFlyWheelDecrementWeightSum[currentGauge][flywheel] += amount;
            ghost_gaugeFlyWheelBoostedTotalSuply[currentGauge][flywheel] -= amount;
        }
    }

    function optIn() internal virtual {
        if (booster.userGaugeflywheelId(currentActor, ERC20(currentGauge), FlywheelCore(currentFlywheel)) != 0) {
            ghost_zeroOptIn++;
            return;
        }
        booster.optIn(ERC20(currentGauge), FlywheelCore(currentFlywheel));

        uint256 id = booster.userGaugeflywheelId(currentActor, ERC20(currentGauge), FlywheelCore(currentFlywheel));
        require(id > 0, "Not opted in - ID is 0");
        require(
            address(booster.userGaugeFlywheels(currentActor, ERC20(currentGauge), id - 1)) == currentFlywheel,
            "Not opted in - flywheel mismatch"
        );

        uint256 userGaugeWeight = gaugeToken.getUserGaugeWeight(currentActor, currentGauge);
        ghost_gaugeFlyWheelIncrementWeightSum[currentGauge][currentFlywheel] += userGaugeWeight;
        ghost_gaugeFlyWheelBoostedTotalSuply[currentGauge][currentFlywheel] += userGaugeWeight;
    }

    function optOut() internal virtual {
        if (
            !_gauges.contains(currentGauge) || !_flywheels.contains(currentFlywheel)
                || booster.userGaugeflywheelId(currentActor, ERC20(currentGauge), FlywheelCore(currentFlywheel)) == 0
        ) {
            ghost_zeroOptOut++;
            return;
        }
        booster.optOut(ERC20(currentGauge), FlywheelCore(currentFlywheel), true);

        require(
            booster.userGaugeflywheelId(currentActor, ERC20(currentGauge), FlywheelCore(currentFlywheel)) == 0,
            "Opted In - opt out failed"
        );

        uint256 userGaugeWeight = gaugeToken.getUserGaugeWeight(currentActor, currentGauge);
        ghost_gaugeFlyWheelDecrementWeightSum[currentGauge][currentFlywheel] += userGaugeWeight;
        ghost_gaugeFlyWheelBoostedTotalSuply[currentGauge][currentFlywheel] -= userGaugeWeight;
    }

    function optIn(uint256 actorSeed, uint256 gaugeSeed, uint256 flywheelSeed, bool advanceEpoch)
        public
        virtual
        advanceOneEpoch(advanceEpoch)
        createActor(actorSeed)
        useGauge(gaugeSeed)
        useFlywheel(flywheelSeed)
        countCall("optIn")
    {
        optIn();
    }

    function optOut(uint256 actorSeed, uint256 gaugeSeed, uint256 flywheelSeed, bool advanceEpoch)
        public
        virtual
        advanceOneEpoch(advanceEpoch)
        useActor(actorSeed)
        useGauge(gaugeSeed)
        useFlywheel(flywheelSeed)
        countCall("optOut")
    {
        optOut();
    }

    function incrementWeight(uint256 actorSeed, uint256 gaugeSeed, uint96 amount, bool advanceEpoch)
        public
        virtual
        advanceOneEpoch(advanceEpoch)
        createActor(actorSeed)
        useGauge(gaugeSeed)
        countCall("incrementWeight")
    {
        incrementGauge(amount);
    }

    function decrementWeight(uint256 actorSeed, uint256 gaugeSeed, uint96 amount, bool advanceEpoch)
        public
        virtual
        advanceOneEpoch(advanceEpoch)
        useActor(actorSeed)
        useGauge(gaugeSeed)
        countCall("decrementWeight")
    {
        decrementGauge(amount);
    }

    function forEachActor(function(address) external func) public {
        return _actors.forEach(func);
    }

    function actors() external view returns (address[] memory) {
        return _actors.addrs;
    }

    function gauges() external view returns (address[] memory) {
        return _gauges.addrs;
    }

    function containsGauge(address gauge) external view returns (bool) {
        return _gauges.contains(gauge);
    }

    function flywheels() external view returns (address[] memory) {
        return _flywheels.addrs;
    }

    function containsFlywheel(address flywheel) external view returns (bool) {
        return _flywheels.contains(flywheel);
    }

    function callSummary() external view {
        console2.log("Call summary:");
        console2.log("-------------------");
        console2.log("optIn", calls["optIn"]);
        console2.log("optOut", calls["optOut"]);
        console2.log("incrementWeight", calls["incrementWeight"]);
        console2.log("decrementWeight", calls["decrementWeight"]);
        console2.log("-------------------");

        console2.log("Increment Weight Sum: \t", ghost_incrementWeightSum);
        console2.log("Decrement Weight Sum: \t", ghost_decrementWeightSum);
        console2.log("-------------------");

        console2.log("Zero Opt In:", ghost_zeroOptIn);
        console2.log("Zero Opt Out:", ghost_zeroOptOut);
        console2.log("Zero Increment Weight:", ghost_zeroIncrementWeight);
        console2.log("Zero Decrement Weight:", ghost_zeroDecrementWeight);
    }

    function _bribeGauge(address gauge, address flywheel, uint256 amount) internal {
        MockERC20 token = MockERC20(FlywheelCore(flywheel).rewardToken());
        token.mint(address(BaseV2Gauge(gauge).multiRewardsDepot()), amount);
    }
}
