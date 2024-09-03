// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {BaseV2Minter} from "./BaseV2Minter.sol";

/// @title Base V2 Minter Admin - allows owner to control `setTailEmissions` while governance handles the rest.
contract BaseV2MinterAdmin is Ownable {
    /// @notice The governor contract that owns BaseV2Minter.
    address public immutable governor;

    /// @notice The BaseV2Minter contract.
    BaseV2Minter public immutable minter;

    /// @notice BaseV2MinterAdmin constructor.
    /// @param _governor The governor contract that owns BaseV2Minter.
    /// @param _minter The BaseV2Minter contract.
    constructor(address _governor, BaseV2Minter _minter, address _owner) {
        _initializeOwner(_owner);
        governor = _governor;
        minter = _minter;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP
    ///////////////////////////////////////////////////////////////*/

    /// @notice Returns ownership over BaseV2Minter back to governance contracts.
    function returnOwnershipToGovernance() external onlyOwner {
        minter.transferOwnership(governor);
    }

    /// @notice Renouncing ownership to zero address in not allowed.
    function renounceOwnership() public payable override {
        revert RenounceOwnershipNotAllowed();
    }

    /*//////////////////////////////////////////////////////////////
                         GOVERNANCE FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Returns ownership over BaseV2Minter back to governance contracts.
    function setOwnershipToGovernance() external onlyGovernance {
        minter.transferOwnership(governor);
    }

    /// @notice Allows governance to set Dao address to receive Dao share of Minter emissions.
    function setDao(address _dao) external onlyGovernance {
        minter.setDao(_dao);
    }

    /// @notice Allows governance to set Dao share of Minter emissions.
    function setDaoShare(uint96 _daoShare) external onlyGovernance {
        minter.setDaoShare(_daoShare);
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    uint96 private constant MIN_TAIL_EMISSION = 10;

    /// @notice Allows owner to set Minter tail emission rate.
    function setTailEmission(uint96 _tailEmission) external onlyOwner {
        if (_tailEmission < MIN_TAIL_EMISSION) revert TailEmissionTooLow();

        minter.setTailEmission(_tailEmission);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Only allows governance contract to call.
    modifier onlyGovernance() {
        if (msg.sender != governor) revert OnlyGovernanceCanCall();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Thrown when tail emission is too low.
    error TailEmissionTooLow();

    /// @notice Thrown when msg sender isn't governance contract.
    error OnlyGovernanceCanCall();

    /// @notice Thrown when someone tries to renounce ownership.
    error RenounceOwnershipNotAllowed();
}
