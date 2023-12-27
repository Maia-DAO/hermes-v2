// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";

import {MultiRewardsDepot} from "@rewards/depots/MultiRewardsDepot.sol";
import {FlywheelBribeRewards} from "@rewards/rewards/FlywheelBribeRewards.sol";
import {FlywheelCore} from "@rewards/FlywheelCoreStrategy.sol";
import {FlywheelGaugeRewards} from "@rewards/rewards/FlywheelGaugeRewards.sol";

import {BaseV2GaugeFactory} from "./factories/BaseV2GaugeFactory.sol";

import {IBaseV2Gauge} from "./interfaces/IBaseV2Gauge.sol";

/// @title Base V2 Gauge - Base contract for handling liquidity provider incentives and voter's bribes.
abstract contract BaseV2Gauge is IBaseV2Gauge {
    using SafeTransferLib for address;

    /*///////////////////////////////////////////////////////////////
                            GAUGE STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2Gauge
    address public immutable override rewardToken;

    /// @notice token to boost gauge rewards
    bHermesBoost public immutable hermesGaugeBoost;

    /// @inheritdoc IBaseV2Gauge
    FlywheelGaugeRewards public immutable override flywheelGaugeRewards;

    /// @inheritdoc IBaseV2Gauge
    address public immutable override strategy;

    /// @inheritdoc IBaseV2Gauge
    MultiRewardsDepot public immutable override multiRewardsDepot;

    /**
     * @notice Constructs the BaseV2Gauge contract.
     * @param _flywheelGaugeRewards The FlywheelGaugeRewards contract.
     * @param _strategy The strategy address.
     */
    constructor(FlywheelGaugeRewards _flywheelGaugeRewards, address _strategy) {
        flywheelGaugeRewards = _flywheelGaugeRewards;
        rewardToken = _flywheelGaugeRewards.rewardToken();
        hermesGaugeBoost = BaseV2GaugeFactory(msg.sender).bHermesBoostToken();
        strategy = _strategy;

        multiRewardsDepot = new MultiRewardsDepot{salt: keccak256(abi.encodePacked(this))}(
            address(BaseV2GaugeFactory(msg.sender).bribesFactory())
        );
    }

    /*///////////////////////////////////////////////////////////////
                        GAUGE ACTIONS    
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2Gauge
    function newEpoch() external override {
        flywheelGaugeRewards.getAccruedRewards();

        uint256 accruedRewards = rewardToken.balanceOf(address(this));

        if (accruedRewards > 0) {
            _distribute(accruedRewards);
            emit Distribute(accruedRewards);
        }
    }

    /// @notice Distributes weekly emissions to the strategy.
    function _distribute(uint256 amount) internal virtual;

    /// @inheritdoc IBaseV2Gauge
    function attachUser(address user) external override onlyStrategy {
        hermesGaugeBoost.attach(user);
    }

    /// @inheritdoc IBaseV2Gauge
    function detachUser(address user) external override onlyStrategy {
        hermesGaugeBoost.detach(user);
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN ACTIONS    
    ///////////////////////////////////////////////////////////////*/

    /// @notice Only the strategy can attach and detach users.
    modifier onlyStrategy() virtual {
        if (msg.sender != strategy) revert StrategyError();
        _;
    }
}
