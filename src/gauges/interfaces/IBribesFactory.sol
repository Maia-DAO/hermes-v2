// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlywheelCore} from "@rewards/FlywheelCoreStrategy.sol";

import {BaseV2GaugeManager} from "../factories/BaseV2GaugeManager.sol";

/**
 * @title Bribes Factory.
 * @notice Responsible for creating new bribe flywheel instances.
 *         Owner has admin rights to add bribe flywheels to gauges.
 */
interface IBribesFactory {
    /*///////////////////////////////////////////////////////////////
                        BRIBES FACTORY STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice Array that holds every bribe created by the factory.
    function bribeFlywheels(uint256) external view returns (FlywheelCore);

    /// @notice Mapping that attributes an id to every bribe created.
    function bribeFlywheelIds(FlywheelCore) external view returns (uint256);

    /// @notice Mapping that holds the address of the bribe token of a given flywheel.
    function tokenToFlywheel(address) external view returns (FlywheelCore);

    /// @notice Returns all the bribes created by the factory.
    function getBribeFlywheels() external view returns (FlywheelCore[] memory);

    /*//////////////////////////////////////////////////////////////
                        CREATE BRIBE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new bribe flywheel to the given gauge.
     * @dev Creates a new bribe flywheel if it doesn't exist.
     * @param gauge address of the gauge to add the bribe to.
     * @param bribeToken address of the token to create a bribe for.
     */
    function addGaugetoFlywheel(address gauge, address bribeToken) external returns (FlywheelCore flywheel);

    /**
     * @notice Creates a new flywheel for the given bribe token address.
     * @param bribeToken address of the token to create a bribe for.
     */
    function createBribeFlywheel(address bribeToken) external returns (FlywheelCore flywheel);

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new bribe flywheel is created.
    event BribeFlywheelCreated(address indexed bribeToken, FlywheelCore indexed flywheel);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Throws when trying to add a bribe flywheel for a token that already exists.
    error BribeFlywheelAlreadyExists();

    /// @notice Throws when trying to add a bribe flywheel for a strategy that is not a gauge.
    error InvalidGauge();

    /// @notice Throws when trying to add a bribe flywheel for zero address.
    error InvalidBribeToken();
}
