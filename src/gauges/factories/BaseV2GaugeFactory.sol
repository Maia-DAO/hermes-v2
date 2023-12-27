// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";
import {BaseV2Gauge} from "@gauges/BaseV2Gauge.sol";

import {BribesFactory} from "./BribesFactory.sol";
import {BaseV2GaugeManager} from "./BaseV2GaugeManager.sol";

import {IBaseV2GaugeFactory} from "../interfaces/IBaseV2GaugeFactory.sol";

/// @title Base V2 Gauge Factory
abstract contract BaseV2GaugeFactory is Ownable, IBaseV2GaugeFactory {
    /*///////////////////////////////////////////////////////////////
                            FACTORY STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeFactory
    BaseV2GaugeManager public immutable override gaugeManager;

    /// @inheritdoc IBaseV2GaugeFactory
    bHermesBoost public immutable override bHermesBoostToken;

    /// @inheritdoc IBaseV2GaugeFactory
    BribesFactory public immutable override bribesFactory;

    /// @inheritdoc IBaseV2GaugeFactory
    BaseV2Gauge[] public override gauges;

    /// @inheritdoc IBaseV2GaugeFactory
    mapping(BaseV2Gauge gauge => uint256 gaugeId) public override gaugeIds;

    /// @inheritdoc IBaseV2GaugeFactory
    mapping(BaseV2Gauge gauge => bool isActive) public override activeGauges;

    /// @inheritdoc IBaseV2GaugeFactory
    mapping(address strategy => BaseV2Gauge gauge) public override strategyGauges;

    /**
     * @notice Creates a new gauge factory
     * @param _gaugeManager The gauge manager to use
     * @param _bHermesBoost The BurntHermes boost token to use
     * @param _bribesFactory The bribes factory to use
     * @param _owner The owner of the factory
     */
    constructor(
        BaseV2GaugeManager _gaugeManager,
        bHermesBoost _bHermesBoost,
        BribesFactory _bribesFactory,
        address _owner
    ) {
        _initializeOwner(_owner);
        bribesFactory = _bribesFactory;
        bHermesBoostToken = _bHermesBoost;
        gaugeManager = _gaugeManager;
    }

    /// @inheritdoc IBaseV2GaugeFactory
    function getGauges() external view override returns (BaseV2Gauge[] memory) {
        return gauges;
    }

    /*//////////////////////////////////////////////////////////////
                         EPOCH LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeFactory
    function newEpoch() external override {
        BaseV2Gauge[] storage _gauges = gauges;

        uint256 length = _gauges.length;
        for (uint256 i = 0; i < length;) {
            if (activeGauges[_gauges[i]]) _gauges[i].newEpoch();

            unchecked {
                i++;
            }
        }
    }

    /// @inheritdoc IBaseV2GaugeFactory
    function newEpoch(uint256 start, uint256 end) external override {
        BaseV2Gauge[] storage _gauges = gauges;

        uint256 length = _gauges.length;
        if (end > length) end = length;

        for (uint256 i = start; i < end;) {
            if (activeGauges[_gauges[i]]) _gauges[i].newEpoch();

            unchecked {
                i++;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                         GAUGE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @notice Creates a new gauge for the given strategy
    /// @param strategy The strategy address to create a gauge for
    /// @param data The information to pass to create a new gauge.
    function createGauge(address strategy, bytes memory data) external onlyOwner returns (BaseV2Gauge gauge) {
        if (address(strategyGauges[strategy]) != address(0)) revert GaugeAlreadyExists();

        gauge = _newGauge(strategy, data);
        strategyGauges[strategy] = gauge;

        uint256 id = gauges.length;
        gauges.push(gauge);
        gaugeIds[gauge] = id;
        activeGauges[gauge] = true;

        gaugeManager.addGauge(address(gauge));

        _afterCreateGauge(strategy, data);
    }

    function _afterCreateGauge(address strategy, bytes memory data) internal virtual;

    function _newGauge(address strategy, bytes memory data) internal virtual returns (BaseV2Gauge gauge);

    /// @inheritdoc IBaseV2GaugeFactory
    function removeGauge(BaseV2Gauge gauge) external override onlyOwner {
        if (!activeGauges[gauge] || gauges[gaugeIds[gauge]] != gauge) revert InvalidGauge();
        delete gauges[gaugeIds[gauge]];
        delete gaugeIds[gauge];
        delete activeGauges[gauge];
        delete strategyGauges[gauge.strategy()];
        gaugeManager.removeGauge(address(gauge));
    }
}
