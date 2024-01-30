// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import "../mocks/MockBaseV2GaugeManager.sol";

error Unauthorized();
error NotAdmin();

contract MockBurntHermes {
    bHermesGauges public immutable gaugeWeight;
    bHermesBoost public immutable gaugeBoost;

    constructor(address _gaugeWeight, address _gaugeBoost) {
        gaugeWeight = bHermesGauges(_gaugeWeight);
        gaugeBoost = bHermesBoost(_gaugeBoost);
    }
}

contract MockGauges {
    function addGauge(address) external {}
    function removeGauge(address) external {}
    function transferOwnership(address) external {}

    function setFlywheelBooster(address) external {}
}

contract BaseV2GaugeManagerTest is Test {
    address _bHermes;
    address _admin = address(0xBCAA);

    address gaugeWeight = address(new MockGauges());
    address gaugeBoost = address(new MockGauges());

    MockBaseV2GaugeManager manager;

    function setUp() public {
        _bHermes = address(new MockBurntHermes(gaugeWeight, gaugeBoost));

        vm.mockCall(address(this), abi.encodeWithSignature("gaugeCycleLength()"), abi.encode(1));
        vm.mockCall(address(this), abi.encodeWithSignature("gaugeCycle()"), abi.encode(type(uint32).max));
        manager = new MockBaseV2GaugeManager(
            BurntHermes(_bHermes), FlywheelGaugeRewards(address(this)), address(this), _admin
        );
    }

    function mockNewEpoch(address gaugeFactory) public {
        vm.mockCall(gaugeFactory, abi.encodeWithSignature("newEpoch()"), "");
    }

    function expectBHermesAddGauge(address gauge) public {
        vm.expectCall(gaugeWeight, abi.encodeWithSignature("addGauge(address)", gauge));
        vm.expectCall(gaugeBoost, abi.encodeWithSignature("addGauge(address)", gauge));
    }

    function expectBHermesRemoveGauge(address gauge) public {
        vm.expectCall(gaugeWeight, abi.encodeWithSignature("removeGauge(address)", gauge));
        vm.expectCall(gaugeBoost, abi.encodeWithSignature("removeGauge(address)", gauge));
    }

    function expectBHermesChangeOwner(address newOwner) public {
        vm.expectCall(gaugeWeight, abi.encodeWithSignature("transferOwnership(address)", newOwner));
        vm.expectCall(gaugeBoost, abi.encodeWithSignature("transferOwnership(address)", newOwner));
    }

    function testNewEpoch(uint80 gaugeFactory) public {
        address gaugeFactory1 = address(uint160(gaugeFactory));
        address gaugeFactory2 = address(uint160(gaugeFactory) + 1);

        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory1));

        manager.changeActiveGaugeFactory(BaseV2GaugeFactory(gaugeFactory1), false);

        manager.newEpoch();

        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory2));

        mockNewEpoch(gaugeFactory2);

        vm.expectCall(gaugeFactory2, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch();
    }

    function testNewEpochRangeSetup(uint80 gaugeFactory) public returns (address, address) {
        address gaugeFactory1 = address(uint160(gaugeFactory));
        address gaugeFactory2 = address(uint160(gaugeFactory) + 1);
        address gaugeFactory3 = address(uint160(gaugeFactory) + 2);
        address gaugeFactory4 = address(uint160(gaugeFactory) + 3);

        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory1));
        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory2));

        manager.changeActiveGaugeFactory(BaseV2GaugeFactory(gaugeFactory1), false);
        manager.changeActiveGaugeFactory(BaseV2GaugeFactory(gaugeFactory2), false);

        manager.newEpoch(0, 2);
        manager.newEpoch(0, 10);
        manager.newEpoch(1, 10);

        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory3));
        testAddGaugeFactory(BaseV2GaugeFactory(gaugeFactory4));

        manager.newEpoch(0, 2);
        manager.newEpoch(1, 2);

        mockNewEpoch(gaugeFactory3);
        mockNewEpoch(gaugeFactory4);

        return (gaugeFactory3, gaugeFactory4);
    }

    function testNewEpochRangeBoth(uint80 gaugeFactory) public {
        (address gaugeFactory3, address gaugeFactory4) = testNewEpochRangeSetup(gaugeFactory);

        vm.expectCall(gaugeFactory3, abi.encodeWithSignature("newEpoch()"));
        vm.expectCall(gaugeFactory4, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch(0, 4);
    }

    function testNewEpochRangeSingle(uint80 gaugeFactory) public {
        (address gaugeFactory3, address gaugeFactory4) = testNewEpochRangeSetup(gaugeFactory);

        manager.changeActiveGaugeFactory(BaseV2GaugeFactory(gaugeFactory3), false);
        vm.expectCall(gaugeFactory4, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch(0, 4);
    }

    function testNewEpochRangeOver(uint80 gaugeFactory) public {
        (address gaugeFactory3, address gaugeFactory4) = testNewEpochRangeSetup(gaugeFactory);

        vm.expectCall(gaugeFactory3, abi.encodeWithSignature("newEpoch()"));
        vm.expectCall(gaugeFactory4, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch(0, 10);
    }

    function testNewEpochRangeUnder(uint80 gaugeFactory) public {
        (address gaugeFactory3, address gaugeFactory4) = testNewEpochRangeSetup(gaugeFactory);

        vm.expectCall(gaugeFactory3, abi.encodeWithSignature("newEpoch()"));
        vm.expectCall(gaugeFactory4, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch(2, 4);
    }

    function testNewEpochRangeOverUnder(uint80 gaugeFactory) public {
        (address gaugeFactory3, address gaugeFactory4) = testNewEpochRangeSetup(gaugeFactory);

        vm.expectCall(gaugeFactory3, abi.encodeWithSignature("newEpoch()"));
        vm.expectCall(gaugeFactory4, abi.encodeWithSignature("newEpoch()"));
        manager.newEpoch(2, 10);
    }

    // TODO - check failing test on mocked call
    // function testAddGauge(address gauge) public {
    //     if (gauge == address(0)) gauge = address(this);

    //     testAddGaugeFactory(BaseV2GaugeFactory(gauge));
    //     assertTrue(manager.activeGaugeFactories(BaseV2GaugeFactory(gauge)));

    //     expectBHermesAddGauge(gauge);

    //     vm.prank(gauge);
    //     manager.addGauge(gauge);
    // }

    function testAddGaugeNotGaugeFactory(address gauge) public {
        if (gauge == address(this)) gauge = address(1);

        testAddGaugeFactory(BaseV2GaugeFactory(gauge));

        assertFalse(manager.activeGaugeFactories(BaseV2GaugeFactory(address(this))));
        vm.expectRevert(IBaseV2GaugeManager.NotActiveGaugeFactory.selector);
        manager.addGauge(gauge);
    }

    function testAddGaugeNotExists(address gauge) public {
        if (gauge == address(this)) gauge = address(1);

        assertFalse(manager.activeGaugeFactories(BaseV2GaugeFactory(gauge)));
        vm.expectRevert(IBaseV2GaugeManager.NotActiveGaugeFactory.selector);
        vm.prank(gauge);
        manager.addGauge(gauge);
    }

    function testRemoveGauge(address gauge) public {
        if (gauge == address(this)) gauge = address(1);

        testAddGaugeFactory(BaseV2GaugeFactory(gauge));
        assertTrue(manager.activeGaugeFactories(BaseV2GaugeFactory(gauge)));
        expectBHermesRemoveGauge(gauge);
        vm.prank(gauge);
        manager.removeGauge(gauge);
    }

    function testRemoveGaugeNotGaugeFactory(address gauge) public {
        testAddGaugeFactory(BaseV2GaugeFactory(gauge));

        assertFalse(manager.activeGaugeFactories(BaseV2GaugeFactory(address(this))));
        vm.expectRevert(IBaseV2GaugeManager.NotActiveGaugeFactory.selector);
        manager.removeGauge(gauge);
    }

    function testRemoveGaugeNotExists(address gauge) public {
        if (gauge == address(this)) gauge = address(1);

        assertFalse(manager.activeGaugeFactories(BaseV2GaugeFactory(gauge)));
        vm.expectRevert(IBaseV2GaugeManager.NotActiveGaugeFactory.selector);
        vm.prank(gauge);
        manager.removeGauge(gauge);
    }

    function testGetGaugeFactories(BaseV2GaugeFactory gaugeFactory, BaseV2GaugeFactory gaugeFactory2) public {
        if (address(gaugeFactory) == address(gaugeFactory2)) {
            if (address(gaugeFactory) == address(0)) gaugeFactory2 = BaseV2GaugeFactory(address(1));
            else gaugeFactory2 = BaseV2GaugeFactory(address(uint160(address(gaugeFactory)) - 1));
        }

        assertEq(manager.getGaugeFactories().length, 0);

        testAddGaugeFactory(gaugeFactory);
        assertEq(manager.getGaugeFactories().length, 1);
        testAddGaugeFactory(gaugeFactory2);
        assertEq(manager.getGaugeFactories().length, 2);
        manager.removeGaugeFactory(gaugeFactory);

        assertEq(manager.getGaugeFactories().length, 2);
        manager.removeGaugeFactory(gaugeFactory2);
        assertEq(manager.getGaugeFactories().length, 2);
    }

    function testAddGaugeFactory(BaseV2GaugeFactory gaugeFactory) public {
        assertEq(manager.gaugeFactoryIds(gaugeFactory), 0);
        uint256 gaugeFactoryIds = manager.getGaugeFactories().length;
        assertFalse(manager.activeGaugeFactories(gaugeFactory));

        manager.addGaugeFactory(gaugeFactory);

        assertEq(manager.gaugeFactoryIds(gaugeFactory), gaugeFactoryIds);
        assertEq(address(manager.gaugeFactories(gaugeFactoryIds)), address(gaugeFactory));
        assertTrue(manager.activeGaugeFactories(gaugeFactory));
    }

    function testAddGaugeFactoryAlreadyExists(BaseV2GaugeFactory gaugeFactory) public {
        testAddGaugeFactory(gaugeFactory);

        vm.expectRevert(IBaseV2GaugeManager.GaugeFactoryAlreadyExists.selector);
        manager.addGaugeFactory(gaugeFactory);
    }

    function testAddGaugeFactoryEvent(BaseV2GaugeFactory gaugeFactory) public {
        vm.expectEmit(true, true, true, true);
        emit AddedGaugeFactory(address(gaugeFactory));
        manager.addGaugeFactory(gaugeFactory);
    }

    function testAddGaugeFactoryNotOwner(address gaugeFactory) public {
        vm.prank(address(0xCAF1));
        vm.expectRevert(Unauthorized.selector);
        manager.addGaugeFactory(BaseV2GaugeFactory(gaugeFactory));
    }

    function testRemoveGaugeFactory(BaseV2GaugeFactory gaugeFactory) public {
        uint256 gaugeFactoryIds = manager.getGaugeFactories().length;
        testAddGaugeFactory(gaugeFactory);

        assertEq(manager.gaugeFactoryIds(gaugeFactory), gaugeFactoryIds);
        assertEq(address(manager.gaugeFactories(gaugeFactoryIds)), address(gaugeFactory));
        assertTrue(manager.activeGaugeFactories(gaugeFactory));

        manager.removeGaugeFactory(gaugeFactory);

        assertEq(manager.gaugeFactoryIds(gaugeFactory), 0);
        assertEq(address(manager.gaugeFactories(manager.gaugeFactoryIds(gaugeFactory))), address(0));
        assertFalse(manager.activeGaugeFactories(gaugeFactory));
    }

    function testRemoveGaugeFactoryEvent(BaseV2GaugeFactory gaugeFactory) public {
        testAddGaugeFactory(gaugeFactory);
        vm.expectEmit(true, true, true, true);
        emit RemovedGaugeFactory(address(gaugeFactory));
        manager.removeGaugeFactory(gaugeFactory);
    }

    function testRemoveGaugeFactoryNotOwner(address gaugeFactory) public {
        vm.prank(address(0xCAF1));
        vm.expectRevert(Unauthorized.selector);
        manager.removeGaugeFactory(BaseV2GaugeFactory(gaugeFactory));
    }

    function testRemoveGaugeFactoryNotActive(BaseV2GaugeFactory gaugeFactory) public {
        if (address(gaugeFactory) == address(0)) gaugeFactory = BaseV2GaugeFactory(address(1));

        vm.expectRevert(IBaseV2GaugeManager.NotActiveGaugeFactory.selector);
        manager.removeGaugeFactory(gaugeFactory);
    }

    function testRemoveGaugeFactoryNotInArray(BaseV2GaugeFactory gaugeFactory) public {
        if (address(gaugeFactory) == address(0)) gaugeFactory = BaseV2GaugeFactory(address(1));

        testAddGaugeFactory(gaugeFactory);
        manager.changeActiveGaugeFactory(gaugeFactory, false);

        vm.expectRevert(IBaseV2GaugeManager.NotActiveGaugeFactory.selector);
        manager.removeGaugeFactory(gaugeFactory);
    }

    function testChangebHermesGaugeOwner(address newOwner) public {
        expectBHermesChangeOwner(newOwner);
        vm.prank(_admin);
        manager.changebHermesGaugeOwner(newOwner);
    }

    function testChangebHermesGaugeOwnerEvent(address newOwner) public {
        expectBHermesChangeOwner(newOwner);

        vm.prank(_admin);
        vm.expectEmit(true, true, true, true);
        emit ChangedbHermesGaugeOwner(newOwner);
        manager.changebHermesGaugeOwner(newOwner);
    }

    function testChangebHermesGaugeOwnerNotAdmin(address newOwner) public {
        vm.expectRevert(NotAdmin.selector);
        manager.changebHermesGaugeOwner(newOwner);
    }

    function testChangeAdmin(address newAdmin) public {
        assertEq(manager.admin(), address(_admin));
        vm.prank(_admin);
        manager.changeAdmin(newAdmin);
        assertEq(manager.admin(), newAdmin);
    }

    function testChangeAdminNotAdmin(address newAdmin) public {
        assertEq(manager.admin(), address(_admin));
        vm.expectRevert(NotAdmin.selector);
        manager.changeAdmin(newAdmin);
    }

    function testChangeAdminEvent(address newAdmin) public {
        vm.prank(_admin);
        vm.expectEmit(true, true, true, true);
        emit ChangedAdmin(newAdmin);
        manager.changeAdmin(newAdmin);
    }

    function testChangeFlywheelBooster(address newFlywheelBooster) public {
        vm.prank(_admin);
        vm.expectCall(gaugeWeight, abi.encodeWithSignature("setFlywheelBooster(address)", newFlywheelBooster));
        manager.changeFlywheelBooster(newFlywheelBooster);
    }

    function testChangeFlywheelBoosterNotAdmin(address newFlywheelBooster) public {
        vm.expectRevert(NotAdmin.selector);
        manager.changeFlywheelBooster(newFlywheelBooster);
    }

    /// @notice Emitted when a new gauge factory is added.
    event AddedGaugeFactory(address indexed gaugeFactory);

    /// @notice Emitted when a gauge factory is removed.
    event RemovedGaugeFactory(address indexed gaugeFactory);

    /// @notice Emitted when changing BurntHermes GaugeWeight and GaugeWeight owner.
    event ChangedbHermesGaugeOwner(address indexed newOwner);

    /// @notice Emitted when changing admin.
    event ChangedAdmin(address indexed newAdmin);
}
