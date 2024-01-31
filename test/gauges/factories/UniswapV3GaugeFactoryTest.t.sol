// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import "@gauges/factories/UniswapV3GaugeFactory.sol";
import {IBaseV2GaugeFactory} from "@gauges/factories/BaseV2GaugeFactory.sol";

error Unauthorized();

contract UniswapV3GaugeFactoryTest is DSTestPlus {
    address gaugeManager = address(0xCAFE);
    address _bHermesBoost = address(0xBCAA);
    address uniswapV3Factory = address(0x5678);
    address nonfungiblePositionManager = address(0x1234);
    address flywheelGaugeRewards = address(0x9ABC);
    address bribesFactory = address(0x12DC);

    UniswapV3GaugeFactory factory;

    MockERC20 rewardToken;

    function setUp() public {
        rewardToken = new MockERC20("Token", "TKN", 18);

        hevm.mockCall(flywheelGaugeRewards, abi.encodeWithSignature("minter()"), abi.encode(address(this)));
        hevm.mockCall(flywheelGaugeRewards, abi.encodeWithSignature("rewardToken()"), abi.encode(rewardToken));
        hevm.mockCall(flywheelGaugeRewards, abi.encodeWithSignature("getAccruedRewards()"), abi.encode(0));

        factory = new UniswapV3GaugeFactory(
            BaseV2GaugeManager(gaugeManager),
            bHermesBoost(_bHermesBoost),
            IUniswapV3Factory(uniswapV3Factory),
            INonfungiblePositionManager(nonfungiblePositionManager),
            FlywheelGaugeRewards(flywheelGaugeRewards),
            BribesFactory(bribesFactory),
            address(this)
        );
    }

    function mockAddGauge(address gauge) public {
        hevm.mockCall(gaugeManager, abi.encodeWithSignature("addGauge(address)"), abi.encode(gauge));
    }

    function mockNewEpoch(address gauge) public {
        hevm.mockCall(gauge, abi.encodeWithSignature("newEpoch()"), "");
    }

    function testNewEpoch(uint80 strategy) public {
        address strategy1 = address(uint160(strategy));
        address strategy2 = address(uint160(strategy) + 1);

        testCreateGauge(strategy1);

        factory.newEpoch();

        address newGauge = testCreateGauge(strategy2);

        mockNewEpoch(newGauge);

        hevm.expectCall(newGauge, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch();
    }

    function testNewEpochRangeSetup(uint80 strategy) public returns (address, address) {
        address strategy1 = address(uint160(strategy));
        address strategy2 = address(uint160(strategy) + 1);
        address strategy3 = address(uint160(strategy) + 2);
        address strategy4 = address(uint160(strategy) + 3);

        testCreateGauge(strategy1);
        testCreateGauge(strategy2);

        factory.newEpoch(0, 2);
        factory.newEpoch(0, 10);
        factory.newEpoch(1, 10);

        address gauge3 = testCreateGauge(strategy3);
        address gauge4 = testCreateGauge(strategy4);

        factory.newEpoch(0, 2);
        factory.newEpoch(1, 2);

        mockNewEpoch(gauge3);
        mockNewEpoch(gauge4);

        return (gauge3, gauge4);
    }

    function testNewEpochRangeBoth(uint80 gauge) public {
        (address gauge3, address gauge4) = testNewEpochRangeSetup(gauge);

        hevm.expectCall(gauge3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gauge4, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch(0, 4);
    }

    function testNewEpochRangeSingle(uint80 gauge) public {
        (, address gauge4) = testNewEpochRangeSetup(gauge);

        hevm.expectCall(gauge4, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch(0, 4);
    }

    function testNewEpochRangeOver(uint80 gauge) public {
        (address gauge3, address gauge4) = testNewEpochRangeSetup(gauge);

        hevm.expectCall(gauge3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gauge4, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch(0, 10);
    }

    function testNewEpochRangeUnder(uint80 gauge) public {
        (address gauge3, address gauge4) = testNewEpochRangeSetup(gauge);

        hevm.expectCall(gauge3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gauge4, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch(2, 4);
    }

    function testNewEpochRangeOverUnder(uint80 gauge) public {
        (address gauge3, address gauge4) = testNewEpochRangeSetup(gauge);

        hevm.expectCall(gauge3, abi.encodeWithSignature("newEpoch()"));
        hevm.expectCall(gauge4, abi.encodeWithSignature("newEpoch()"));
        factory.newEpoch(2, 10);
    }

    function testCreateGauge(address strategy) public returns (address gauge) {
        if (strategy == address(0)) strategy = address(0xBEEF);

        mockAddGauge(strategy);

        assertEq(address(factory.strategyGauges(strategy)), address(0));
        uint256 gaugesIds = factory.getGauges().length;
        assertEq(factory.gaugeIds(BaseV2Gauge(strategy)), 0);
        assertFalse(factory.activeGauges(BaseV2Gauge(strategy)));

        gauge = address(factory.createGauge(strategy, abi.encodePacked(uint256(0))));

        assertEq(address(factory.strategyGauges(strategy)), gauge);
        assertEq(address(factory.gauges(gaugesIds)), gauge);
        assertEq(factory.gaugeIds(BaseV2Gauge(gauge)), gaugesIds);
        assertTrue(factory.activeGauges(BaseV2Gauge(gauge)));
    }

    function testAlreadyCreated(address strategy) public {
        if (strategy == address(0)) strategy = address(0xBEEF);

        testCreateGauge(strategy);

        hevm.expectRevert(IBaseV2GaugeFactory.GaugeAlreadyExists.selector);
        factory.createGauge(strategy, "");
    }

    function testCreateRemoveCreate(address strategy) public {
        testRemoveGauge(strategy);
        testCreateGauge(strategy);
    }

    function testCreateGaugeNotOwner(address strategy) public {
        hevm.prank(address(0xCAF1));
        hevm.expectRevert(Unauthorized.selector);
        factory.createGauge(strategy, "");
    }

    function testRemoveGauge(address strategy) public returns (BaseV2Gauge gauge) {
        if (strategy == address(0)) strategy = address(0xBEEF);

        gauge = BaseV2Gauge(testCreateGauge(strategy));

        assertEq(address(factory.gauges(factory.gaugeIds(gauge))), address(gauge));
        assertTrue(factory.activeGauges(gauge));
        assertEq(address(factory.strategyGauges(strategy)), address(gauge));

        factory.removeGauge(gauge);

        assertEq(address(factory.gauges(factory.gaugeIds(gauge))), address(0));
        assertFalse(factory.activeGauges(gauge));
        assertEq(address(factory.strategyGauges(strategy)), address(0));
    }

    function testAlreadyRemoved(address strategy) public {
        BaseV2Gauge gauge = testRemoveGauge(strategy);

        hevm.expectRevert(IBaseV2GaugeFactory.InvalidGauge.selector);
        factory.removeGauge(gauge);
    }

    function testDoesntExist(BaseV2Gauge gauge) public {
        hevm.expectRevert(IBaseV2GaugeFactory.InvalidGauge.selector);
        factory.removeGauge(gauge);
    }

    function testRemoveGaugeNotOwner(BaseV2Gauge gauge) public {
        hevm.prank(address(0xCAF1));
        hevm.expectRevert(Unauthorized.selector);
        factory.removeGauge(gauge);
    }

    function testGetGauges(address strategy) public {
        address strategy1 = address(uint160(strategy));
        address strategy2 = address(uint160(strategy) + 1);

        assertEq(factory.getGauges().length, 0);

        BaseV2Gauge gauge = BaseV2Gauge(testCreateGauge(strategy1));
        assertEq(factory.getGauges().length, 1);
        BaseV2Gauge gauge2 = BaseV2Gauge(testCreateGauge(strategy2));
        assertEq(factory.getGauges().length, 2);

        factory.removeGauge(gauge);
        assertEq(factory.getGauges().length, 2);
        factory.removeGauge(gauge2);
        assertEq(factory.getGauges().length, 2);
    }

    function testSetMinimumWidth(address strategy, uint24 minimumWidth) public {
        UniswapV3Gauge gauge = UniswapV3Gauge(testCreateGauge(strategy));
        assertEq(factory.getGauges().length, 1);

        assertEq(gauge.minimumWidth(), 0);

        factory.setMinimumWidth(address(gauge), minimumWidth);
        assertEq(gauge.minimumWidth(), minimumWidth);
    }

    function testSetMinimumWidthNotOwner(address strategy, uint24 minimumWidth) public {
        UniswapV3Gauge gauge = UniswapV3Gauge(testCreateGauge(strategy));
        assertEq(factory.getGauges().length, 1);

        hevm.prank(address(0xCAF1));
        hevm.expectRevert(Unauthorized.selector);
        factory.setMinimumWidth(address(gauge), minimumWidth);
    }

    function testSetMinimumWidthInvalidGauge(address strategy, uint24 minimumWidth) public {
        UniswapV3Gauge(testCreateGauge(strategy));
        assertEq(factory.getGauges().length, 1);

        hevm.expectRevert(IBaseV2GaugeFactory.InvalidGauge.selector);
        factory.setMinimumWidth(address(0), minimumWidth);
    }
}
