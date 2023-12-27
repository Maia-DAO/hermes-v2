// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {bHermesBoost} from "./tokens/bHermesBoost.sol";
import {bHermesGauges} from "./tokens/bHermesGauges.sol";
import {bHermesVotes as ERC20Votes} from "./tokens/bHermesVotes.sol";

import {IUtilityManager} from "./interfaces/IUtilityManager.sol";

/// @title Utility Tokens Manager Contract
abstract contract UtilityManager is IUtilityManager {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                         UTILITY MANAGER STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUtilityManager
    bHermesGauges public immutable override gaugeWeight;
    /// @inheritdoc IUtilityManager
    bHermesBoost public immutable override gaugeBoost;
    /// @inheritdoc IUtilityManager
    ERC20Votes public immutable override governance;

    /// @inheritdoc IUtilityManager
    mapping(address user => uint256 claimedWeight) public override userClaimedWeight;
    /// @inheritdoc IUtilityManager
    mapping(address user => uint256 claimedBoost) public override userClaimedBoost;
    /// @inheritdoc IUtilityManager
    mapping(address user => uint256 claimedGovernance) public override userClaimedGovernance;

    /**
     * @notice Constructs the UtilityManager contract.
     * @param _gaugeWeight The address of the bHermesGauges contract.
     * @param _gaugeBoost The address of the bHermesBoost contract.
     * @param _governance The address of the bHermesVotes contract.
     */
    constructor(address _gaugeWeight, address _gaugeBoost, address _governance) {
        gaugeWeight = bHermesGauges(_gaugeWeight);
        gaugeBoost = bHermesBoost(_gaugeBoost);
        governance = ERC20Votes(_governance);
    }

    /*///////////////////////////////////////////////////////////////
                        UTILITY TOKENS LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUtilityManager
    function forfeitOutstanding() public virtual override {
        forfeitWeight(userClaimedWeight[msg.sender]);
        forfeitBoost(userClaimedBoost[msg.sender]);
        forfeitGovernance(userClaimedGovernance[msg.sender]);
    }

    /// @inheritdoc IUtilityManager
    function forfeitMultiple(uint256 amount) public virtual override {
        forfeitWeight(amount);
        forfeitBoost(amount);
        forfeitGovernance(amount);
    }

    /// @inheritdoc IUtilityManager
    function forfeitMultipleAmounts(uint256 weight, uint256 boost, uint256 _governance) public virtual override {
        forfeitWeight(weight);
        forfeitBoost(boost);
        forfeitGovernance(_governance);
    }

    /// @inheritdoc IUtilityManager
    function forfeitWeight(uint256 amount) public virtual override {
        if (amount == 0) return;
        userClaimedWeight[msg.sender] -= amount;
        address(gaugeWeight).safeTransferFrom(msg.sender, address(this), amount);

        emit ForfeitWeight(msg.sender, amount);
    }

    /// @inheritdoc IUtilityManager
    function forfeitBoost(uint256 amount) public virtual override {
        if (amount == 0) return;
        userClaimedBoost[msg.sender] -= amount;
        address(gaugeBoost).safeTransferFrom(msg.sender, address(this), amount);

        emit ForfeitBoost(msg.sender, amount);
    }

    /// @inheritdoc IUtilityManager
    function forfeitGovernance(uint256 amount) public virtual override {
        if (amount == 0) return;
        userClaimedGovernance[msg.sender] -= amount;
        address(governance).safeTransferFrom(msg.sender, address(this), amount);

        emit ForfeitGovernance(msg.sender, amount);
    }

    /// @inheritdoc IUtilityManager
    function claimMultiple(uint256 amount) public virtual override {
        claimWeight(amount);
        claimBoost(amount);
        claimGovernance(amount);
    }

    /// @inheritdoc IUtilityManager
    function claimMultipleAmounts(uint256 weight, uint256 boost, uint256 _governance) public virtual override {
        claimWeight(weight);
        claimBoost(boost);
        claimGovernance(_governance);
    }

    /// @inheritdoc IUtilityManager
    function claimWeight(uint256 amount) public virtual override checkWeight(amount) {
        if (amount == 0) return;
        userClaimedWeight[msg.sender] += amount;
        address(gaugeWeight).safeTransfer(msg.sender, amount);

        emit ClaimWeight(msg.sender, amount);
    }

    /// @inheritdoc IUtilityManager
    function claimBoost(uint256 amount) public virtual override checkBoost(amount) {
        if (amount == 0) return;
        userClaimedBoost[msg.sender] += amount;
        address(gaugeBoost).safeTransfer(msg.sender, amount);

        emit ClaimBoost(msg.sender, amount);
    }

    /// @inheritdoc IUtilityManager
    function claimGovernance(uint256 amount) public virtual override checkGovernance(amount) {
        if (amount == 0) return;
        userClaimedGovernance[msg.sender] += amount;
        address(governance).safeTransfer(msg.sender, amount);

        emit ClaimGovernance(msg.sender, amount);
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    /// @dev Checks available weight allows for call.
    modifier checkWeight(uint256 amount) virtual;

    /// @dev Checks available boost allows for call.
    modifier checkBoost(uint256 amount) virtual;

    /// @dev Checks available governance allows for call.
    modifier checkGovernance(uint256 amount) virtual;
}
