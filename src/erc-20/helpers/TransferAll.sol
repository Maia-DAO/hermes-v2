// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @title A contract for transferring the `balanceOf` a token the caller
/// @author Maia DAO
/// @dev The sender needs to approve this contract before calling
contract TransferAll {
    using SafeTransferLib for address;

    /*///////////////////////////////////////////////////////////////
                            VIEW HELPERS
    ///////////////////////////////////////////////////////////////*/

    function transferAll(address token, address to) external returns (uint256) {
        return token.safeTransferAllFrom(msg.sender, to);
    }
}
