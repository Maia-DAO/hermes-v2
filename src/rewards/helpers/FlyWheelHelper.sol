// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

/**
 * @title Flywheel Core Incentives Manager
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Flywheel is a general framework for managing token incentives.
 *          It takes reward streams to various *strategies* such as staking LP tokens
 *          and divides them among *users* of those strategies.
 *
 *          The Core contract maintains three important pieces of state:
 *           - The rewards index which determines how many rewards are owed per token per strategy.
 *           - User indexes track how far behind the strategy they are to lazily calculate all catch-up rewards.
 *           - The accrued (unclaimed) rewards per user.
 *           - References to the booster and rewards module are described below.
 *
 *          Core does not manage any tokens directly. The rewards module maintains token balances,
 *          and approves core to pull and transfer them to users when they claim.
 *
 *          SECURITY NOTE: For maximum accuracy and to avoid exploits:
 *          Rewards accrual should be notified atomically through the accrue hook.
 *          Accrue should be called any time tokens are transferred, minted, or burned.
 */
interface IFlywheelCore {
    /*///////////////////////////////////////////////////////////////
                        FLYWHEEL CORE STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice The token to reward
    function rewardToken() external view returns (address);

    /*///////////////////////////////////////////////////////////////
                        ACCRUE/CLAIM LOGIC
    ///////////////////////////////////////////////////////////////*/
    /**
     * @notice accrue rewards for a single user on a strategy
     *   @param strategy the strategy to accrue a user's rewards on
     *   @param user the user to be accrued
     *   @return the cumulative amount of rewards accrued to user (including prior)
     */
    function accrue(ERC20 strategy, address user) external returns (uint256);
}

/// @title A helper contract for querying Flywheel contracts
/// @author Maia DAO
/// @dev Do not use this contract on-chain, it is for off-chain use only. As they modify state.
contract FlyWheelHelper {
    /*///////////////////////////////////////////////////////////////
                            VIEW HELPERS
    ///////////////////////////////////////////////////////////////*/

    function getRewards(IFlywheelCore flywheel, ERC20 strategy, address account, address rewardsDepot)
        external
        returns (uint256, uint256)
    {
        (, bytes memory data) = address(this).call(
            abi.encodeWithSelector(this.getRewardsRevert.selector, flywheel, strategy, account, rewardsDepot)
        );

        uint256 accruedRewards;
        uint256 nextRewards;

        assembly ("memory-safe") {
            // Load the last 64 bytes of the return data (skip first 4 + 128 bytes)
            accruedRewards := mload(add(data, 0x64))
            nextRewards := mload(add(data, 0x84))
        }

        return (accruedRewards, nextRewards);
    }

    function getRewardsRevert(IFlywheelCore flywheel, ERC20 strategy, address account, address rewardsDepot) external {
        uint256 accruedRewards = flywheel.accrue(strategy, account);
        uint256 nextRewards = ERC20(flywheel.rewardToken()).balanceOf(rewardsDepot);

        revert(string(abi.encode(accruedRewards, nextRewards)));
    }
}
