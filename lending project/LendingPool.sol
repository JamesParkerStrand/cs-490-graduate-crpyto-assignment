// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IPriceOracle.sol";
import "./InterestRateModel.sol";

contract LendingPool {
    struct Position {
        uint256 collateral;
        uint256 debt;
        uint256 lastUpdate;
    }

    mapping(address => Position) public positions;

    IPriceOracle public oracle;
    InterestRateModel public rateModel;

    uint256 public collateralFactor = 75;
    uint256 public liquidationThreshold = 85;

    constructor(address _oracle, address _rateModel) {
        oracle = IPriceOracle(_oracle);
        rateModel = InterestRateModel(_rateModel);
    }

    receive() external payable {}

    // --- Deposit Collateral (ETH) ---
    function depositCollateral() external payable {
        require(msg.value > 0, "Invalid amount");

        Position storage p = positions[msg.sender];

        p.collateral += msg.value;
        p.lastUpdate = block.timestamp;
    }

    // --- Borrow ETH ---
    function borrow(uint256 amount) external {
        _accrueInterest(msg.sender);

        Position storage p = positions[msg.sender];

        uint256 price = oracle.getETHPrice();

        uint256 maxBorrow =
            (p.collateral * price * collateralFactor) /
            (100 * 1e18);

        require(p.debt + amount <= maxBorrow, "Exceeds limit");
        require(address(this).balance >= amount, "Insufficient liquidity");

        p.debt += amount;
        p.lastUpdate = block.timestamp;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    // --- Repay ETH ---
    function repay() external payable {
        require(msg.value > 0, "Invalid amount");

        Position storage p = positions[msg.sender];

        _accrueInterest(msg.sender);

        if (msg.value >= p.debt) {
            p.debt = 0;
        } else {
            p.debt -= msg.value;
        }

        p.lastUpdate = block.timestamp;
    }

    // --- Liquidation ---
    function liquidate(address user) external {
        _accrueInterest(user);

        Position storage p = positions[user];

        uint256 price = oracle.getETHPrice();

        uint256 maxAllowedDebt =
            (p.collateral * price * liquidationThreshold) /
            (100 * 1e18);

        require(p.debt > maxAllowedDebt, "Position healthy");

        uint256 collateral = p.collateral;

        delete positions[user];

        (bool success,) = payable(msg.sender).call{value: collateral}("");
        require(success, "Transfer failed");
    }

    // --- Internal interest accrual ---
    function _accrueInterest(address user) internal {
        Position storage p = positions[user];

        if (p.debt == 0 || p.lastUpdate == 0) return;

        uint256 timeElapsed = block.timestamp - p.lastUpdate;

        uint256 utilization =
            (p.debt * 1e18) / (p.collateral + 1);

        uint256 rate = rateModel.getBorrowRate(utilization);

        uint256 interest =
            (p.debt * rate * timeElapsed) /
            (365 days * 100);

        p.debt += interest;
        p.lastUpdate = block.timestamp;
    }
}