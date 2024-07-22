// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import {TransferAll} from "../src/erc-20/helpers/TransferAll.sol";

/*
forge script --broadcast \
--rpc-url <RPC-URL> \
script/deployParameters/Deploy<network>.s.sol:Deploy<network> \
--etherscan-api-key <ETHERSCAN-API-KEY> \
--verify
 */

contract DeployTransferAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TransferAll transferAll = new TransferAll();
        console2.log("TransferAll Deployed:", address(transferAll));

        vm.stopBroadcast();
    }
}
