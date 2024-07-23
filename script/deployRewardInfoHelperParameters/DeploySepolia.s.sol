// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../DeployRewardInfoHelper.s.sol";

contract DeploySepolia is DeployRewardInfoHelper {
    function setUp() public override {
        params = RewardInfoHelperParameters({
            factory: 0x0227628f3F023bb0B980b67D528571c95c6DaC1c,
            nonfungiblePositionManager: 0x1238536071E1c677A632429e3655c799b22cDA52,
            staker: 0x2907fA8B81AD03F07A6545901957e7a9D1dD252B
        });
    }
}
