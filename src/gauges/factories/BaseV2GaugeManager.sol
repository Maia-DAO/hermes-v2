// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {BurntHermes, bHermesGauges} from "@hermes/BurntHermes.sol";
import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";

import {FlywheelGaugeRewards} from "@rewards/rewards/FlywheelGaugeRewards.sol";

import {BaseV2GaugeFactory} from "./BaseV2GaugeFactory.sol";

import {IBaseV2GaugeManager} from "../interfaces/IBaseV2GaugeManager.sol";

/// @title Base V2 Gauge Factory Manager - Manages addition/removal of Gauge Factories to BurntHermes.
contract BaseV2GaugeManager is Ownable, IBaseV2GaugeManager {
    /*///////////////////////////////////////////////////////////////
                        GAUGE MANAGER STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeManager
    address public admin;

    /// @inheritdoc IBaseV2GaugeManager
    bHermesGauges public immutable bHermesGaugeWeight;

    /// @inheritdoc IBaseV2GaugeManager
    bHermesBoost public immutable bHermesGaugeBoost;

    FlywheelGaugeRewards public immutable rewards;

    /// @inheritdoc IBaseV2GaugeManager
    BaseV2GaugeFactory[] public gaugeFactories;

    /// @inheritdoc IBaseV2GaugeManager
    mapping(BaseV2GaugeFactory gaugeFactory => uint256 gaugeFactoryId) public gaugeFactoryIds;

    /// @inheritdoc IBaseV2GaugeManager
    mapping(BaseV2GaugeFactory gaugeFactory => bool isActive) public activeGaugeFactories;

    /**
     * @notice Initializes Base V2 Gauge Factory Manager contract.
     * @param _bHermes BurntHermes contract
     * @param _owner can add BaseV2GaugeFactories.
     * @param _admin can transfer ownership of bHermesWeight and bHermesBoost.
     */
    constructor(BurntHermes _bHermes, FlywheelGaugeRewards _rewards, address _owner, address _admin) {
        admin = _admin;
        _initializeOwner(_owner);
        rewards = _rewards;
        bHermesGaugeWeight = _bHermes.gaugeWeight();
        bHermesGaugeBoost = _bHermes.gaugeBoost();
    }

    /// @inheritdoc IBaseV2GaugeManager
    function getGaugeFactories() external view returns (BaseV2GaugeFactory[] memory) {
        return gaugeFactories;
    }

    /*//////////////////////////////////////////////////////////////
                            EPOCH LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeManager
    function newEpoch() external override {
        BaseV2GaugeFactory[] storage _gaugeFactories = gaugeFactories;

        uint256 length = _gaugeFactories.length;
        for (uint256 i = 0; i < length;) {
            if (activeGaugeFactories[_gaugeFactories[i]]) _gaugeFactories[i].newEpoch();

            unchecked {
                i++;
            }
        }
    }

    /// @inheritdoc IBaseV2GaugeManager
    function newEpoch(uint256 start, uint256 end) external override {
        BaseV2GaugeFactory[] storage _gaugeFactories = gaugeFactories;

        uint256 length = _gaugeFactories.length;
        if (end > length) end = length;

        for (uint256 i = start; i < end;) {
            if (activeGaugeFactories[_gaugeFactories[i]]) _gaugeFactories[i].newEpoch();

            unchecked {
                i++;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            GAUGE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeManager
    function addGauge(address gauge) external override onlyActiveGaugeFactory rewardsAreQueuedForThisCycle {
        bHermesGaugeWeight.addGauge(gauge);
        bHermesGaugeBoost.addGauge(gauge);
    }

    /// @inheritdoc IBaseV2GaugeManager
    function removeGauge(address gauge) external override onlyActiveGaugeFactory rewardsAreQueuedForThisCycle {
        bHermesGaugeWeight.removeGauge(gauge);
        bHermesGaugeBoost.removeGauge(gauge);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeManager
    function addGaugeFactory(BaseV2GaugeFactory gaugeFactory) external override onlyOwner {
        if (activeGaugeFactories[gaugeFactory]) revert GaugeFactoryAlreadyExists();

        gaugeFactoryIds[gaugeFactory] = gaugeFactories.length;
        gaugeFactories.push(gaugeFactory);
        activeGaugeFactories[gaugeFactory] = true;

        emit AddedGaugeFactory(address(gaugeFactory));
    }

    /// @inheritdoc IBaseV2GaugeManager
    function removeGaugeFactory(BaseV2GaugeFactory gaugeFactory) external override onlyOwner {
        if (!activeGaugeFactories[gaugeFactory] || gaugeFactories[gaugeFactoryIds[gaugeFactory]] != gaugeFactory) {
            revert NotActiveGaugeFactory();
        }
        delete gaugeFactories[gaugeFactoryIds[gaugeFactory]];
        delete gaugeFactoryIds[gaugeFactory];
        delete activeGaugeFactories[gaugeFactory];

        emit RemovedGaugeFactory(address(gaugeFactory));
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeManager
    function changebHermesGaugeOwner(address newOwner) external override onlyAdmin {
        bHermesGaugeWeight.transferOwnership(newOwner);
        bHermesGaugeBoost.transferOwnership(newOwner);

        emit ChangedbHermesGaugeOwner(newOwner);
    }

    /// @inheritdoc IBaseV2GaugeManager
    function changeAdmin(address newAdmin) external override onlyAdmin {
        admin = newAdmin;

        emit ChangedAdmin(newAdmin);
    }

    /// @inheritdoc IBaseV2GaugeManager
    function changeFlywheelBooster(address newFlywheelBooster) external onlyAdmin {
        bHermesGaugeWeight.setFlywheelBooster(newFlywheelBooster);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    modifier onlyActiveGaugeFactory() {
        if (!activeGaugeFactories[BaseV2GaugeFactory(msg.sender)]) revert NotActiveGaugeFactory();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier rewardsAreQueuedForThisCycle() {
        uint256 currentCycle;
        unchecked {
            currentCycle = (block.timestamp / 1 weeks) * 1 weeks;
        }
        if (currentCycle > rewards.gaugeCycle()) revert RewardsNotQueued();
        _;
    }
}
