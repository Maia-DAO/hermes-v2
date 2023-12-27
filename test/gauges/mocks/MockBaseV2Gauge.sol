// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@gauges/BaseV2Gauge.sol";

contract MockBaseV2Gauge is BaseV2Gauge {
    constructor(FlywheelGaugeRewards _flywheelGaugeRewards, address _strategy)
        BaseV2Gauge(_flywheelGaugeRewards, _strategy)
    {}

    function _distribute(uint256 amount) internal override {}
}
