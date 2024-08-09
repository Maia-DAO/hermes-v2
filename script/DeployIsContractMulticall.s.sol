// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "forge-std/Script.sol";

/**
 * @title  Address Code Size Library
 * @notice Library for checking the size of a contract's code.
 * @dev    Used for checking if an address is a contract or an EOA.
 */
library AddressCodeSize {
    /*///////////////////////////////////////////////////////////////
                   PAYLOAD DECODING POSITIONAL CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly ("memory-safe") {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function isEOA(address addr) internal view returns (bool) {
        uint256 size;
        assembly ("memory-safe") {
            size := extcodesize(addr)
        }
        return size == 0;
    }
}

contract IsContractMulticall {
    function isContract(address addr) external view returns (bool) {
        return AddressCodeSize.isContract(addr);
    }

    function isContract(address[] calldata addrs) external view returns (bool[] memory) {
        bool[] memory results = new bool[](addrs.length);
        for (uint256 i = 0; i < addrs.length; i++) {
            results[i] = AddressCodeSize.isContract(addrs[i]);
        }
        return results;
    }
}

/*
forge script --broadcast \
--rpc-url <RPC-URL> \
script/deployParameters/Deploy<network>.s.sol:Deploy<network> \
--etherscan-api-key <ETHERSCAN-API-KEY> \
--verify
 */

contract DeployIsContractMulticall is Script {
    function run() external {
        vm.startBroadcast();

        IsContractMulticall isContractMulticall = new IsContractMulticall();
        console2.log("IsContractMulticall Deployed:", address(isContractMulticall));

        vm.stopBroadcast();
    }
}
