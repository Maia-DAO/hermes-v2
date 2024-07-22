// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlywheelCore} from "@rewards/FlywheelCoreStrategy.sol";
import {FlywheelGaugeRewards} from "@rewards/rewards/FlywheelGaugeRewards.sol";
import {MultiRewardsDepot} from "@rewards/depots/MultiRewardsDepot.sol";

/**
 * @title Base V2 Gauge
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Handles rewards for distribution, boost attaching/detaching and
 *          accruing bribes for a given strategy.
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡤⠒⠈⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⢤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠑⠦⣄⠀⠀⢀⣠⠖⢶⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠑⢤⡈⠳⣦⡀⠀⠀⠀⠀⠀⠀⠒⢦⣀⠀⠀⠈⢱⠖⠉⠀⠀⠀⠳⡄⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣌⣻⣦⡀⠀⠀⠀⠀⠀⠀⠈⠳⢄⢠⡏⠀⠀⠐⠀⠀⠀⠘⡀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠙⢿⣿⣄⠈⠓⢄⠀⠀⠀⠀⠈⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⢀⡴⠁⠀⠀⠀⡠⠂⠀⠀⠀⡾⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢦⠀⠀⠀⠀⠀⠑⢄⠀⠀⠙⢿⣦⠀⠀⠑⢄⠀⠀⢰⠃⠀⠀⠀⠀⢀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⢠⠞⠀⠀⠀⠀⢰⠃⠀⠀⠀⠀⠧⠀⠀⠀⠀⠀⡄⠀⠀⠀⠀⠀⠈⢧⠀⠀⠀⠀⠀⠈⠳⣄⠀⠀⠙⢷⡀⠀⠀⠙⢦⡘⢦⠀⠀⠀⠺⢿⠇⢀⠀⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⢠⠎⠀⠀⠀⠀⢀⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⡆⡀⠀⠀⠀⠈⣦⠀⠀⠀⠀⠀⠀⠈⢦⡀⠀⠀⠙⢦⡀⠀⠀⠑⢾⡇⠀⠀⠀⠈⢠⡟⠁⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠁⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⢠⠀⠀⠀⠀⠀⠀⢳⠀⢣⣧⠀⠀⠀⠀⠘⡆⠑⡀⠀⠀⠀⠀⠐⡝⢄⠀⠀⠀⠹⢆⠀⠀⢈⡷⠀⠀⠀⢠⡟⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⢸⣦⠀⠀⠀⠀⠀⢸⡄⢸⢹⣄⣆⠀⠀⠀⠸⡄⠹⡄⠀⠀⠀⠀⠈⢎⢧⡀⠀⠀⠈⠳⣤⡿⠛⠳⡀⠀⡉⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢸⠇⠀⠀⠀⡇⠀⢸⢸⠀⠀⠀⠀⠀⠘⣿⠀⣿⣿⡙⡄⠀⠀⠀⠹⡄⠘⡄⠀⠀⠀⠀⠈⢧⡱⡄⠀⠀⠀⠛⢷⣦⣤⣽⣶⣶⣶⣦⣤⣸⣀⡀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠸⠀⠀⠀⠀⡇⠀⢸⡸⡆⠀⠀⠀⠀⠀⣿⣇⣿⣿⣷⣽⡖⠒⠒⠊⢻⡉⠹⡏⠒⠂⠀⠀⠀⠳⡜⣦⡀⠀⠀⠀⠹⣿⡟⠋⣿⡻⣯⣍⠉⡉⠛⠶⣄⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢠⠀⠀⠀⠀⡇⡀⠸⡇⣧⢂⠀⠀⠀⢰⡸⣿⡿⢻⡇⠁⠹⣆⠀⠀⠈⢷⡀⠹⡾⣆⠀⠀⠀⠀⠙⣎⠟⣦⣀⣀⣴⣿⠀⣼⣿⢷⣌⠻⢷⣦⣄⣸⠇⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⢹⣇⠀⣧⢹⡟⡄⠀⠀⠀⣿⢿⠀⡀⢻⡀⠘⣎⢇⢀⣀⣨⣿⣦⠹⣾⣧⡀⠀⠀⣀⣨⠶⠾⣿⣿⣿⣿⣶⡿⣼⡞⠙⢷⣵⡈⠉⠉⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢸⢠⣠⠤⠒⢺⣿⠒⢿⡼⣿⣳⡀⠀⣠⠋⢿⠆⠰⡄⢳⣤⠼⣿⣯⣶⠿⠿⠿⠿⢿⣿⣷⣶⣿⠁⠀⠀⠀⣻⣿⣿⣿⣿⣷⣿⢡⢇⣾⢻⣿⣶⣄⡀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢰⣼⢾⡀⠀⠀⠸⣿⡇⠈⣧⢹⡛⢣⡴⠃⠀⠘⣿⡀⣨⠾⣿⣾⠟⢩⣷⣿⣶⣤⠀⠀⠈⢿⡿⣿⠀⠀⠀⠀⢹⢿⣿⣿⣿⣿⠋⢻⠏⢹⣸⠁⠈⠛⠿⣶⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿⣇⠀⠀⠀⣿⢹⡄⢻⣧⢷⠛⣧⠀⠀⠀⠈⣿⣧⣾⣿⠁⠀⣾⣿⣿⣷⣾⡇⠀⠀⡜⠀⢸⠀⠀⠀⠀⢸⡄⢻⣿⣿⠋⠀⢸⠀⠀⣿⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⢸⣄⠠⣶⣻⣖⣷⡘⣇⠈⢧⠘⣷⠶⠒⠊⠙⣿⠟⠁⠀⠀⢹⡿⣿⣿⢿⠇⠀⠐⠁⠀⢼⠀⠀⠀⠀⡼⢸⠻⣿⣧⣀⠀⠀⢀⣼⢹⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿⣿⣿⠟⠛⠛⣿⣿⣿⣦⡈⠠⠘⠆⠀⠀⠈⠁⠀⠀⠀⠀⠈⠛⠶⠞⠋⠀⠀⠀⡀⢠⡏⠀⠀⠀⢠⡇⣼⢸⣿⡟⠉⢣⣠⢾⡇⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢀⣨⢿⡿⣟⢿⡄⠀⠀⣿⣿⣯⣿⡃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⡇⠀⠀⠀⣼⡿⢱⣿⣿⠁⠀⠈⡇⢸⡇⢠⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢋⠁⠈⡇⠘⣆⠑⢄⠀⠘⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠇⠀⠀⢠⢿⣷⣿⣿⣿⡄⠀⠰⠃⣼⡇⢸⠀⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⢻⠀⢹⣆⠀⠁⢤⡌⠓⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⠀⠀⢠⡏⢸⣿⣿⣿⡿⠻⡄⣠⣾⣿⡇⢸⠦⠀⠀⠀ ⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠈⡇⠀⢸⡆⢸⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡸⡏⠀⢀⡟⠀⣾⣿⣿⣿⠀⠀⣽⠁⢸⣿⣷⢸⡇⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⢸⡇⢸⣿⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⠁⢠⡟⠀⢰⣿⣿⣿⣿⠀⢠⠇⢠⣾⡇⢿⡈⡇⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠈⠃⢸⣿⣿⣷⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⣿⡏⢀⠎⠀⠀⡼⣽⠋⠁⠈⢀⣾⣴⣿⣿⡇⠸⡇⢱⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢠⡇⠀⠀⠀⢸⣿⠑⢹⣿⣄⠀⠀⠀⠀⠀⠀⠀⠀⠐⠂⠀⠀⠀⠀⠀⠀⠀⠀⣠⣾⣿⠋⢠⠟⠀⠀⣸⣷⠃⠀⢀⡞⠁⢸⣿⣿⣿⣧⠀⢿⣸⠀⠀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⢻⠃⠀⠀⠀⣿⡇⠀⣼⣿⣿⣷⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣿⠇⡴⠃⠀⠀⣰⣟⡏⠀⡠⠋⢀⣠⣿⣿⡏⠈⣿⡇⠘⣏⣆⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⢀⡾⠀⠀⠀⢠⣿⠀⠀⣿⣿⡿⢹⣿⡿⠷⣶⣤⣀⡀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣷⢧⡞⠁⠀⠀⣸⣿⠼⠷⢶⣶⣾⣿⡿⣿⡿⠀⠀⠘⣷⠀⠸⣿⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠊⠀⠀⠀⠀⣼⠇⠀⣸⣿⡿⢡⣿⡟⠀⣠⣾⣿⣿⣿⣷⣦⣤⣀⣠⣾⣿⣿⣿⣿⣛⣋⣀⣀⣠⢞⡟⠀⣀⡠⢾⣿⣿⡟⠀⢿⣧⠀⠀⠀⠘⡆⠀⠙⡇⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⡟⠀⢠⣿⠟⢀⣿⡟⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠋⠉⠁⠀⠉⠉⠉⠑⠻⢭⡉⠉⠀⢸⡆⢿⡗⠀⠈⢿⡀⠀⠀⠀⠹⡄⠀⢱⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⢀⡼⠁⠀⢀⡞⠉⢠⡿⣌⣴⣿⣿⣿⣿⣿⣿⣿⣿⡿⠛⠋⡿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠲⣄⢸⡇⠘⡇⠀⠀⠈⢧⠀⠀⠀⠀⢱⡀⠈⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⣠⠞⠁⠀⣠⠏⠀⣰⣿⣿⣿⡿⠟⠿⠛⣩⣾⡿⠛⠁⠀⢀⣼⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⡇⠀⠸⡄⠀⠀⠈⢇⠀⠀⠀⠀⢻⡀⠀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠁⠀⠀⣠⠇⣠⣾⣿⠿⠛⠁⢀⣠⣴⣿⠟⠁⠀⠀⠀⢰⠋⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⡀⠀⠹⡄⠀⠀⠘⢆⠀⠀⠀⠀⠳⡀⠀⠀⠀
 * ⠀⠀⠀⠀⠀⠀⠀⠀⣀⣴⣫⡾⠟⠋⢁⣀⣤⣶⣿⡟⠋⠀⠀⣀⣠⣤⣾⡿⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⡄⠀⢹⡄⠀⠀⠈⢧⡀⠀⠀⠀⠙⣔⡄⠀
 */
interface IBaseV2Gauge {
    /*///////////////////////////////////////////////////////////////
                            GAUGE STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice the reward token paid
    function rewardToken() external returns (address);

    /// @notice the flywheel core contract
    function flywheelGaugeRewards() external returns (FlywheelGaugeRewards);

    /// @notice the gauge's strategy contract
    function strategy() external returns (address);

    /// @notice the gauge's rewards depot
    function multiRewardsDepot() external returns (MultiRewardsDepot);

    /*///////////////////////////////////////////////////////////////
                        GAUGE ACTIONS    
    ///////////////////////////////////////////////////////////////*/

    /// @notice function responsible for updating current epoch
    /// @dev should be called once per week, or any outstanding rewards will be kept for next cycle
    function newEpoch() external;

    /// @notice attaches a gauge to a user
    /// @dev only the strategy can call this function
    function attachUser(address user) external;

    /// @notice detaches a gauge to a users
    /// @dev only the strategy can call this function
    function detachUser(address user) external;

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when weekly emissions are distributed
     * @param amount amount of tokens distributed
     */
    event Distribute(uint256 indexed amount);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @notice thrown when caller is not the strategy
    error StrategyError();
}
