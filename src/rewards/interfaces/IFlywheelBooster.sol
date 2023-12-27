// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/rewards/IFlywheelBooster.sol)
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {FlywheelCore} from "@rewards/FlywheelCoreStrategy.sol";

/**
 * @title Balance Booster Module for Flywheel
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Flywheel is a general framework for managing token incentives.
 *          It takes reward streams to various *strategies* such as staking LP tokens
 *          and divides them among *users* of those strategies.
 *
 *          The Booster module is an optional module for virtually boosting or otherwise transforming user balances.
 *          If a booster is not configured, the strategies ERC-20 balanceOf/totalSupply will be used instead.
 *
 *          Boosting logic can be associated with referrals, vote-escrow, or other strategies.
 *
 *          SECURITY NOTE: Similar to how Core needs to be notified any time the strategy user composition changes,
 *          the booster would need to be notified of any conditions which change the boosted balances atomically.
 *          This prevents gaming of the reward calculation function by using manipulated balances when accruing.
 *
 *          NOTE: Gets total and user voting power allocated to each strategy.
 *
 *          ⣿⡇⣿⣿⣿⠛⠁⣴⣿⡿⠿⠧⠹⠿⠘⣿⣿⣿⡇⢸⡻⣿⣿⣿⣿⣿⣿⣿
 *          ⢹⡇⣿⣿⣿⠄⣞⣯⣷⣾⣿⣿⣧⡹⡆⡀⠉⢹⡌⠐⢿⣿⣿⣿⡞⣿⣿⣿
 *          ⣾⡇⣿⣿⡇⣾⣿⣿⣿⣿⣿⣿⣿⣿⣄⢻⣦⡀⠁⢸⡌⠻⣿⣿⣿⡽⣿⣿
 *          ⡇⣿⠹⣿⡇⡟⠛⣉⠁⠉⠉⠻⡿⣿⣿⣿⣿⣿⣦⣄⡉⠂⠈⠙⢿⣿⣝⣿
 *          ⠤⢿⡄⠹⣧⣷⣸⡇⠄⠄⠲⢰⣌⣾⣿⣿⣿⣿⣿⣿⣶⣤⣤⡀⠄⠈⠻⢮
 *          ⠄⢸⣧⠄⢘⢻⣿⡇⢀⣀⠄⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡀⠄⢀
 *          ⠄⠈⣿⡆⢸⣿⣿⣿⣬⣭⣴⣿⣿⣿⣿⣿⣿⣿⣯⠝⠛⠛⠙⢿⡿⠃⠄⢸
 *          ⠄⠄⢿⣿⡀⣿⣿⣿⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣿⣿⣿⣿⡾⠁⢠⡇⢀
 *          ⠄⠄⢸⣿⡇⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣏⣫⣻⡟⢀⠄⣿⣷⣾
 *          ⠄⠄⢸⣿⡇⠄⠈⠙⠿⣿⣿⣿⣮⣿⣿⣿⣿⣿⣿⣿⣿⡿⢠⠊⢀⡇⣿⣿
 *          ⠒⠤⠄⣿⡇⢀⡲⠄⠄⠈⠙⠻⢿⣿⣿⠿⠿⠟⠛⠋⠁⣰⠇⠄⢸⣿⣿⣿
 *          ⠄⠄⠄⣿⡇⢬⡻⡇⡄⠄⠄⠄⡰⢖⠔⠉⠄⠄⠄⠄⣼⠏⠄⠄⢸⣿⣿⣿
 *          ⠄⠄⠄⣿⡇⠄⠙⢌⢷⣆⡀⡾⡣⠃⠄⠄⠄⠄⠄⣼⡟⠄⠄⠄⠄⢿⣿⣿
 */
interface IFlywheelBooster {
    /*///////////////////////////////////////////////////////////////
                        FLYWHEEL BOOSTER STATE
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the flywheel bribe at index to accrue rewards for a given user per strategy.
     *   @param user the user to get bribes for
     *   @param strategy the strategy to get bribes for
     *   @return flywheel bribe to accrue rewards for a given user for a strategy
     */
    function userGaugeFlywheels(address user, ERC20 strategy, uint256 index) external returns (FlywheelCore flywheel);

    /**
     * @notice Gets the index + 1 of the flywheel in userGaugeFlywheels array. 0 means not opted in.
     *   @param user the user to get the flywheel index for
     *   @param strategy the strategy to get the flywheel index for
     *   @param flywheel the flywheel to get the index for
     *   @return id the index + 1 of the flywheel in userGaugeFlywheels array. 0 means not opted in.
     */
    function userGaugeflywheelId(address user, ERC20 strategy, FlywheelCore flywheel) external returns (uint256 id);

    /**
     * @notice Gets the gauge weight for a given strategy.
     *   @param strategy the strategy to get the gauge weight for
     *   @param flywheel the flywheel to get the gauge weight for
     *   @return gaugeWeight the gauge weight for a given strategy
     */
    function flywheelStrategyGaugeWeight(ERC20 strategy, FlywheelCore flywheel)
        external
        returns (uint256 gaugeWeight);

    /*///////////////////////////////////////////////////////////////
                            VIEW HELPERS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the flywheel bribes to accrue rewards for a given user per strategy.
     *   @param user the user to get bribes for
     *   @param strategy the strategy to get bribes for
     *   @return flywheel bribes to accrue rewards for a given user per strategy
     */
    function getUserGaugeFlywheels(address user, ERC20 strategy) external returns (FlywheelCore[] memory flywheel);

    /**
     * @notice calculate the boosted supply of a strategy.
     *   @param strategy the strategy to calculate boosted supply of
     *   @return the boosted supply
     */
    function boostedTotalSupply(ERC20 strategy) external view returns (uint256);

    /**
     * @notice Calculate the boosted balance of a user in a given strategy.
     *   @param strategy the strategy to calculate boosted balance of
     *   @param user the user to calculate boosted balance of
     *   @return the boosted balance
     */
    function boostedBalanceOf(ERC20 strategy, address user) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                        USER BRIBE OPT-IN/OPT-OUT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice opt-in to a flywheel for a strategy
     *   @param strategy the strategy to opt-in to
     *   @param flywheel the flywheel to opt-in to
     */
    function optIn(ERC20 strategy, FlywheelCore flywheel) external;

    /**
     * @notice opt-out of a flywheel for a strategy
     *   @param strategy the strategy to opt-out of
     *   @param flywheel the flywheel to opt-out of
     *   @param accrue whether or not to accrue rewards before opting out
     */
    function optOut(ERC20 strategy, FlywheelCore flywheel, bool accrue) external;

    /*///////////////////////////////////////////////////////////////
                       bHERMES GAUGE WEIGHT ACCRUAL
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice accrue gauge weight for a user for a strategy before increasing their gauge weight
     *   @param user the user to accrue gauge weight for
     *   @param strategy the strategy to accrue gauge weight for
     *   @param delta the amount of gauge weight to accrue
     */
    function accrueBribesPositiveDelta(address user, ERC20 strategy, uint256 delta) external;

    /**
     * @notice accrue gauge weight for a user for a strategy before decreasing their gauge weight
     *   @param user the user to accrue gauge weight for
     *   @param strategy the strategy to accrue gauge weight for
     *   @param delta the amount of gauge weight to accrue
     */
    function accrueBribesNegativeDelta(address user, ERC20 strategy, uint256 delta) external;

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @notice error thrown when a user is already opted into a flywheel for a strategy
    error AlreadyOptedIn();

    /// @notice error thrown when a user tries to opt out of a flywheel they are not opted in to
    error NotOptedIn();

    /// @notice Throws when trying to opt-in to a strategy that is not a gauge.
    error InvalidGauge();

    /// @notice Throws when trying to opt-in to an invalid flywheel.
    error InvalidFlywheel();
}
