// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ERC4626} from "@ERC4626/ERC4626.sol";

import {HERMES} from "@hermes/tokens/HERMES.sol";

import {IRewardsStream} from "@rewards/interfaces/IFlywheelGaugeRewards.sol";
import {FlywheelGaugeRewards} from "@rewards/rewards/FlywheelGaugeRewards.sol";

/**
 * @title Base V2 Minter
 *  @author Maia DAO (https://github.com/Maia-DAO)
 *  @notice Codifies the minting rules as per b(3,3), abstracted from the token to support
 *          any ERC4626 with any token that allows minting. Responsible for minting new tokens.
 */
interface IBaseV2Minter is IRewardsStream {
    /*//////////////////////////////////////////////////////////////
                         MINTER STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice Underlying token that the contract has minting powers over.
    function underlying() external view returns (address);

    /// @notice ERC4626 vault that receives emissions via rebases,
    ///         which later will be distributed to the depositors.
    function vault() external view returns (ERC4626);

    /// @notice Holds the rewards for the current cycle and distributes them to the gauges.
    function flywheelGaugeRewards() external view returns (FlywheelGaugeRewards);

    /// @notice Represents the address of the DAO.
    function dao() external view returns (address);

    /// @notice Represents the percentage of the emissions that will be sent to the DAO.
    function daoShare() external view returns (uint96);

    /// @notice Represents the percentage of the circulating supply
    ///         that will be distributed every epoch as rewards
    function tailEmission() external view returns (uint96);

    /// @notice Represents the weekly emissions.
    function weekly() external view returns (uint256);

    /// @notice Represents the timestamp of the beginning of the new cycle.
    function activePeriod() external view returns (uint256);

    /**
     * @notice Initializes contract state. Called once when the contract is
     *         deployed to initialize the contract state.
     * @param _flywheelGaugeRewards address of the flywheel gauge rewards contract.
     */
    function initialize(FlywheelGaugeRewards _flywheelGaugeRewards) external;

    /*//////////////////////////////////////////////////////////////
                         ADMIN LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Changes the current tail emissions.
     * @param _tailEmission amount to set as the tail emission
     */
    function setTailEmission(uint96 _tailEmission) external;

    /**
     * @notice Sets the address of the DAO.
     * @param _dao address of the DAO.
     */
    function setDao(address _dao) external;

    /**
     * @notice Sets the share of the DAO rewards.
     * @param _daoShare share of the DAO rewards.
     */
    function setDaoShare(uint96 _daoShare) external;

    /*//////////////////////////////////////////////////////////////
                         EMISSION LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @notice Calculates circulating supply as total token supply - locked supply
    function circulatingSupply() external view returns (uint256);

    /// @notice Calculates tail end (infinity) emissions, starts set as 2% of total supply.
    function weeklyEmission() external view returns (uint256);

    /**
     * @notice Calculate inflation and adjust burn balances accordingly.
     * @param _minted Amount of minted bHermes
     */
    function calculateGrowth(uint256 _minted) external view returns (uint256);

    /**
     * @notice Updates critical information surrounding emissions, such as
     *         the weekly emissions, and mints the tokens for the previous week rewards.
     *         Update period can only be called once per cycle (1 week)
     */
    function updatePeriod() external;

    /**
     * @notice Distributes the weekly emissions to flywheelGaugeRewards contract.
     * @return totalQueuedForCycle represents the amounts of rewards to be distributed.
     */
    function getRewards() external returns (uint256 totalQueuedForCycle);

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Emitted when weekly emissions are minted.
    event Mint(uint256 indexed weekly, uint256 indexed circulatingSupply, uint256 indexed growth, uint256 daoShare);

    /// @notice Emitted when the DAO address changes.
    event ChangedDao(address indexed dao);

    /// @notice Emitted when the DAO share changes.
    event ChangedDaoShare(uint256 indexed daoShare);

    /// @notice Emitted when the tail emission changes.
    event ChangedTailEmission(uint256 indexed tailEmission);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @dev Throws when the caller of `getRewards()` is not the flywheelGaugeRewards contract.
    error NotFlywheelGaugeRewards();

    /// @dev Throws when the caller of `intialize()` is not the initializer contract.
    error NotInitializer();

    /// @dev Throws when new tail emission is higher than 10%.
    error TailEmissionTooHigh();

    /// @dev Throws when the new dao share is higher than 30%.
    error DaoShareTooHigh();

    /// @dev Throws when the updating dao share without a dao set.
    error DaoRewardsAreDisabled();
}
