// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPriceOracle {
    function getETHPrice() external view returns (uint256); // ETH price in USD (1e18)
}