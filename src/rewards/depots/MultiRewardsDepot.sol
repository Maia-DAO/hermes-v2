// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {RewardsDepot} from "./RewardsDepot.sol";

import {IMultiRewardsDepot} from "../interfaces/IMultiRewardsDepot.sol";

/// @title Multiple Rewards Depot - Contract for multiple reward token storage
contract MultiRewardsDepot is Ownable, RewardsDepot, IMultiRewardsDepot {
    /*///////////////////////////////////////////////////////////////
                        REWARDS DEPOT STATE
    ///////////////////////////////////////////////////////////////*/

    /// @dev _assets[rewardsContracts] => asset (reward Token)
    mapping(address rewardsContracts => address rewardToken) private _assets;

    /// @notice _isAsset[asset] => true/false
    mapping(address rewardToken => address rewardsContracts) private _rewardsContracts;

    /**
     * @notice MultiRewardsDepot constructor
     *  @param _owner owner of the contract
     */
    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    /*///////////////////////////////////////////////////////////////
                        GET REWARDS LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultiRewardsDepot
    function getRewards() external override(RewardsDepot, IMultiRewardsDepot) returns (uint256) {
        address asset = _assets[msg.sender];
        if (asset == address(0)) revert FlywheelRewardsError();

        return transferRewards(asset, msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultiRewardsDepot
    function addAsset(address rewardsContract, address asset) external onlyOwner {
        if (_rewardsContracts[asset] != address(0)) revert ErrorAddingAsset();
        _rewardsContracts[asset] = rewardsContract;
        _assets[rewardsContract] = asset;

        emit AssetAdded(rewardsContract, asset);
    }
}
