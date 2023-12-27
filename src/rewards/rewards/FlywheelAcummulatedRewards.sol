// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/FlywheelDynamicRewards.sol)
pragma solidity ^0.8.0;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {BaseFlywheelRewards, FlywheelCore} from "../base/BaseFlywheelRewards.sol";

import {IFlywheelAcummulatedRewards} from "../interfaces/IFlywheelAcummulatedRewards.sol";

///  @title Flywheel Accumulated Rewards.
abstract contract FlywheelAcummulatedRewards is BaseFlywheelRewards, IFlywheelAcummulatedRewards {
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                        REWARDS CONTRACT STATE
    ///////////////////////////////////////////////////////////////*/

    uint256 private constant REWARDS_CYCLE_LENGTH = 1 weeks;

    /// @inheritdoc IFlywheelAcummulatedRewards
    mapping(ERC20 strategy => uint256 endCycle) public override endCycles;

    /**
     * @notice Flywheel Instant Rewards constructor.
     *  @param _flywheel flywheel core contract
     */
    constructor(FlywheelCore _flywheel) BaseFlywheelRewards(_flywheel) {}

    /*//////////////////////////////////////////////////////////////
                        FLYWHEEL CORE FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFlywheelAcummulatedRewards
    function getAccruedRewards(ERC20 strategy) external override onlyFlywheel returns (uint256 amount) {
        uint256 endCycle = endCycles[strategy];

        // if cycle has ended, reset cycle and transfer all available
        if (block.timestamp >= endCycle) {
            if (endCycle != 0) amount = getNextCycleRewards(strategy);

            unchecked {
                // reset for next cycle
                uint256 newEndCycle =
                    ((block.timestamp + REWARDS_CYCLE_LENGTH) / REWARDS_CYCLE_LENGTH) * REWARDS_CYCLE_LENGTH;
                endCycles[strategy] = newEndCycle;

                emit NewRewardsCycle(amount);
            }
        } else {
            amount = 0;
        }
    }

    /// @notice function to get the next cycle's reward amount
    function getNextCycleRewards(ERC20 strategy) internal virtual returns (uint256);
}
