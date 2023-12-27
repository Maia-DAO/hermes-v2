// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RewardsDepot, IRewardsDepot} from "./RewardsDepot.sol";

/// @title Single Rewards Depot - Contract for a single reward token storage
contract SingleRewardsDepot is RewardsDepot {
    /*///////////////////////////////////////////////////////////////
                        REWARDS DEPOT STATE
    ///////////////////////////////////////////////////////////////*/

    /// @dev asset (reward Token) to be stored and distributed for rewards.
    address private immutable asset;

    /// @dev rewardsContract to send all pending rewards to
    address private immutable rewardsContract;

    /**
     * @notice SingleRewardsDepot constructor
     *  @param _asset asset to be stored and distributed for rewards.
     */
    constructor(address _asset) {
        asset = _asset;
        rewardsContract = msg.sender;
    }

    /*///////////////////////////////////////////////////////////////
                        GET REWARDS LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRewardsDepot
    function getRewards() external override returns (uint256 balance) {
        address _rewardsContract = rewardsContract;
        if (msg.sender != address(_rewardsContract)) revert FlywheelRewardsError();
        return transferRewards(asset, _rewardsContract);
    }
}
