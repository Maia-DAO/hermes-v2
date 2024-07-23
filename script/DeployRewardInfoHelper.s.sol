// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import "../src/uni-v3-staker/helpers/RewardInfoHelper.sol";

struct RewardInfoHelperParameters {
    address factory;
    address nonfungiblePositionManager;
    address staker;
}

/*
forge script --broadcast \
--rpc-url <RPC-URL> \
script/deployParameters/Deploy<network>.s.sol:Deploy<network> \
--etherscan-api-key <ETHERSCAN-API-KEY> \
--verify
 */

abstract contract DeployRewardInfoHelper is Script {
    RewardInfoHelperParameters internal params;

    // set values for params and unsupported
    function setUp() public virtual;

    function run() external {
        vm.startBroadcast();

        logParams();

        RewardInfoHelper rewardInfoHelper = new RewardInfoHelper(
            IUniswapV3Factory(params.factory),
            INonfungiblePositionManager(params.nonfungiblePositionManager),
            IUniswapV3Staker(params.staker)
        );
        console2.log("RewardInfoHelper Deployed:", address(rewardInfoHelper));

        vm.stopBroadcast();
    }

    function logParams() internal view {
        console2.log("factory:", address(params.factory));
        console2.log("nonfungiblePositionManager:", address(params.nonfungiblePositionManager));
        console2.log("staker:", address(params.staker));
    }
}
