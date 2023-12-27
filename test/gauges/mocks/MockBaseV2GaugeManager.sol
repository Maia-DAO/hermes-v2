// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@gauges/factories/BaseV2GaugeManager.sol";

contract MockBaseV2GaugeManager is BaseV2GaugeManager {
    constructor(BurntHermes _bHermes, FlywheelGaugeRewards _rewards, address _owner, address _admin)
        BaseV2GaugeManager(_bHermes, _rewards, _owner, _admin)
    {}

    function changeActiveGaugeFactory(BaseV2GaugeFactory gaugeFactory, bool state) external {
        activeGaugeFactories[gaugeFactory] = state;
    }
}
