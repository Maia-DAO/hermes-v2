// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/FlywheelDynamicRewards.sol)
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {FlywheelCore} from "../base/FlywheelCore.sol";
import {RewardsDepot} from "../depots/RewardsDepot.sol";
import {FlywheelAcummulatedRewards} from "../rewards/FlywheelAcummulatedRewards.sol";

import {IFlywheelBribeRewards} from "../interfaces/IFlywheelBribeRewards.sol";

/// @title Flywheel Accumulated Bribes Reward Stream
contract FlywheelBribeRewards is Ownable, FlywheelAcummulatedRewards, IFlywheelBribeRewards {
    /*//////////////////////////////////////////////////////////////
                        REWARDS CONTRACT STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFlywheelBribeRewards
    mapping(ERC20 reward => RewardsDepot depot) public override rewardsDepots;

    /**
     * @notice Flywheel Accumulated Bribes Reward Stream constructor.
     *  @param _flywheel flywheel core contract
     */
    constructor(FlywheelCore _flywheel) FlywheelAcummulatedRewards(_flywheel) {
        _initializeOwner(msg.sender);
    }

    /// @notice calculate and transfer accrued rewards to flywheel core
    function getNextCycleRewards(ERC20 strategy) internal override returns (uint256) {
        return rewardsDepots[strategy].getRewards();
    }

    /// @inheritdoc IFlywheelBribeRewards
    function setRewardsDepot(address strategy, RewardsDepot rewardsDepot) external override onlyOwner {
        rewardsDepots[ERC20(strategy)] = rewardsDepot;

        emit AddRewardsDepot(strategy, rewardsDepot);
    }
}
