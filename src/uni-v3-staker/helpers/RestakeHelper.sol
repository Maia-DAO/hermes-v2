// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title A helper contract to re-stake multiple NFTs on Hermes Uniswap V3 Staker
/// @author Maia DAO
/// @dev This contract is meant to be used in layer 2, optimizing for calldata size
contract RestakeHelper {
    /*///////////////////////////////////////////////////////////////
                               CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V3 Staker contract
    // NOTE: This is a constant for easier use in assembly
    address private constant STAKER = 0x76FA1b6bCaB28e8171027aC0f89D7DB870ed07d6;

    /*///////////////////////////////////////////////////////////////
                                FALLBACK
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Fallback function to allow for multiple NFT re-staking in a single call
     * @dev Receives bytes of token ids to re-stake in the format of [tokenId1, tokenId2, ...], each tokenId is bytes4
     *      At the time of writing, 3 bytes is enough to save all token ids in Arbitrum
     *
     * NOTE: Because this contract never handles funds, we avoid as many checks as possible to save gas
     */
    fallback() external {
        assembly ("memory-safe") {
            // Get the calldata size
            let size := calldatasize()
            // Calculate the number of token IDs (size / 4 bytes per tokenId)
            let numTokenIds := div(size, 0x04)
            // Initialize a counter for the token IDs processed
            let counter := 0

            // Loop through the calldata in chunks of 32 bytes
            for { let i := 0 } lt(i, size) { i := add(i, 0x20) } {
                // Load 32 bytes from calldata starting at position i
                let data := calldataload(i)

                // Process each tokenId in the loaded data
                for { let j := 0 } lt(j, 0x20) { j := add(j, 0x04) } {
                    if or(eq(counter, numTokenIds), gt(counter, numTokenIds)) { break }

                    // Extract the 4 bytes (tokenId) from the loaded data to memory
                    mstore(0x04, and(shr(sub(224, mul(j, 8)), data), 0xffffffff))
                    // Save re-stake function signature in first 4 bytes of memory
                    mstore(0x00, 0xba81a90a00000000000000000000000000000000000000000000000000000000) // `restakeToken(uint256)`

                    // We don't check the return value because we don't care about the result
                    pop(call(gas(), STAKER, 0, 0, 0x24, 0, 0))

                    // Increment the tokenId counter
                    counter := add(counter, 1)
                }
            }
        }
    }
}
