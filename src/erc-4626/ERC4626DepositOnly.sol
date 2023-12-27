// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC4626, ERC4626, ERC20} from "./ERC4626.sol";

/// @title Minimal Deposit Only ERC4626 tokenized Vault implementation
/// @author Maia DAO (https://github.com/Maia-DAO)
abstract contract ERC4626DepositOnly is ERC4626 {
    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    ///////////////////////////////////////////////////////////////*/

    constructor(ERC20 _asset, string memory _name, string memory _symbol) ERC4626(_asset, _name, _symbol) {}

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626
    function withdraw(uint256, address, address) public pure override returns (uint256) {
        revert DepositOnly();
    }

    /// @inheritdoc IERC4626
    function redeem(uint256, address, address) public pure override returns (uint256) {
        revert DepositOnly();
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256) public pure override returns (uint256) {
        revert DepositOnly();
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256) public pure override returns (uint256) {
        revert DepositOnly();
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC4626
    function maxWithdraw(address) public pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address) public pure override returns (uint256) {
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    ///////////////////////////////////////////////////////////////*/

    function beforeWithdraw(uint256, uint256) internal override {}

    /*//////////////////////////////////////////////////////////////
                                ERROR
    ///////////////////////////////////////////////////////////////*/

    error DepositOnly();
}
