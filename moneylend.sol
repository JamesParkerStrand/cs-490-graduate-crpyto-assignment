// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LendingStorage {

    /*//////////////////////////////////////////////////////////////
                               ENUMS
    //////////////////////////////////////////////////////////////*/

    enum LoanStatus {
        None,
        Requested,
        Active,
        Repaid,
        Liquidated,
        Cancelled
    }

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Loan {
        uint256 id;
        address borrower;
        address lender;

        uint256 principal;        // Amount borrowed
        uint256 interestRate;     // e.g. 500 = 5.00% (basis points)
        uint256 startTime;
        uint256 duration;         // in seconds
        uint256 amountRepaid;

        LoanStatus status;
        Collateral collateral;
    }

    struct Collateral {
        address token;            // address(0) if native ETH
        uint256 amount;
    }

    struct LenderPosition {
        uint256 totalSupplied;
        uint256 totalWithdrawn;
        uint256 activeLoansCount;
    }

    struct BorrowerProfile {
        uint256 totalBorrowed;
        uint256 totalRepaid;
        uint256 activeLoansCount;
    }

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public nextLoanId;

    // loanId => Loan
    mapping(uint256 => Loan) public loans;

    // borrower => list of loanIds
    mapping(address => uint256[]) public borrowerLoans;

    // lender => list of loanIds
    mapping(address => uint256[]) public lenderLoans;

    // lender => position data
    mapping(address => LenderPosition) public lenderPositions;

    // borrower => borrower stats
    mapping(address => BorrowerProfile) public borrowerProfiles;

    // supported collateral tokens
    mapping(address => bool) public supportedCollateralTokens;

    /*//////////////////////////////////////////////////////////////
                         OPTIONAL POOL STRUCT
    //////////////////////////////////////////////////////////////*/

    struct LendingPool {
        uint256 totalLiquidity;
        uint256 totalBorrowed;
        uint256 availableLiquidity;
    }

    LendingPool public pool;
}