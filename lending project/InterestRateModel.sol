// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract InterestRateModel {
    uint256 public baseRate;
    uint256 public slope;

    constructor(uint256 _baseRate, uint256 _slope) {
        baseRate = _baseRate;
        slope = _slope;
    }

    function getBorrowRate(uint256 utilization) external view returns (uint256) {
        return baseRate + (slope * utilization) / 1e18;
    }
}