// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Boost} from "../interfaces/IERC20Boost.sol";

/// @title A helper contract for querying ERC20Boost
/// @author Maia DAO
/// @dev Do not use this contract on-chain, it is for off-chain use only. As they modify state.
contract ERC20BoostHelper {
    /*///////////////////////////////////////////////////////////////
                                STATE
    ///////////////////////////////////////////////////////////////*/

    IERC20Boost public immutable erc20Boost;

    /*///////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    ///////////////////////////////////////////////////////////////*/

    constructor(IERC20Boost _erc20Boost) {
        erc20Boost = _erc20Boost;
    }

    /*///////////////////////////////////////////////////////////////
                            VIEW HELPERS
    ///////////////////////////////////////////////////////////////*/

    function getUserBoost(address account) external returns (uint256) {
        erc20Boost.updateUserBoost(account);
        return erc20Boost.getUserBoost(account);
    }
}
