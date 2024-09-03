// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../DeployRewardInfoHelper.s.sol";

contract DeployArbitrum is DeployRewardInfoHelper {
    function setUp() public override {
        params = RewardInfoHelperParameters({
            factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            nonfungiblePositionManager: 0xC36442b4a4522E871399CD717aBDD847Ab11FE88,
            staker: 0x76FA1b6bCaB28e8171027aC0f89D7DB870ed07d6
        });
    }
}
