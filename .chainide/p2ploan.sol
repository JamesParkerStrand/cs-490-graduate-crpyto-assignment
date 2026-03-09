// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LendingStorage {

    /*//////////////////////////////////////////////////////////////
                               INTERFACES
    //////////////////////////////////////////////////////////////*/

    interface IERC20 {
        function transfer(address to, uint256 value) external returns (bool);
        function transferFrom(address from,address to,uint256 value) external returns (bool);
    }

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

        uint256 principal;
        uint256 interestRate; // basis points
        uint256 startTime;
        uint256 duration;
        uint256 amountRepaid;

        LoanStatus status;
        Collateral collateral;
    }

    struct Collateral {
        address token; // address(0) = ETH
        uint256 amount;
    }

    struct LenderPosition {
        uint256 totalLent;
        uint256 activeLoans;
    }

    struct BorrowerProfile {
        uint256 totalBorrowed;
        uint256 activeLoans;
        uint256 repaidLoans;
    }

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event PublicLoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 principal,
        uint256 interestRate,
        uint256 duration
    );

    event LoanFunded(
        uint256 indexed loanId,
        address indexed lender
    );

    event LoanRepaid(
        uint256 indexed loanId
    );

    event LoanLiquidated(
        uint256 indexed loanId
    );

    event LoanCancelled(
        uint256 indexed loanId
    );

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public nextLoanId;

    mapping(uint256 => Loan) public loans;

    mapping(address => uint256) public borrowerLoans;

    mapping(address => uint256) public lenderLoans;

    mapping(address => LenderPosition) public lenderPositions;

    mapping(address => BorrowerProfile) public borrowerProfiles;

    mapping(address => bool) public supportedCollateralTokens;

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _transferCollateralOut(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(token).transfer(to, amount);
        }
    }

    function _receiveCollateral(address token, uint256 amount) internal {
        if (token == address(0)) {
            require(msg.value == amount, "Incorrect ETH collateral");
        } else {
            require(msg.value == 0, "ETH not expected");
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        }
    }

    function _interest(uint256 principal, uint256 rate) internal pure returns (uint256) {
        return (principal * rate) / 10000;
    }

    /*//////////////////////////////////////////////////////////////
                        CREATE PUBLIC LOAN
    //////////////////////////////////////////////////////////////*/

    function createPublicLoanForUse(
        uint256 principal,
        uint256 interestRate,
        uint256 duration,
        address collateralToken,
        uint256 collateralAmount
    ) external payable returns (uint256 loanId) {

        require(principal > 0, "Invalid principal");
        require(duration > 0, "Invalid duration");
        require(collateralAmount > 0, "Invalid collateral");

        if (collateralToken != address(0)) {
            require(
                supportedCollateralTokens[collateralToken],
                "Unsupported collateral"
            );
        }

        require(
            borrowerLoans[msg.sender] == 0,
            "Borrower already has active loan"
        );

        _receiveCollateral(collateralToken, collateralAmount);

        loanId = ++nextLoanId;

        loans[loanId] = Loan({
            id: loanId,
            borrower: msg.sender,
            lender: address(0),
            principal: principal,
            interestRate: interestRate,
            startTime: 0,
            duration: duration,
            amountRepaid: 0,
            status: LoanStatus.Requested,
            collateral: Collateral({
                token: collateralToken,
                amount: collateralAmount
            })
        });

        borrowerLoans[msg.sender] = loanId;

        borrowerProfiles[msg.sender].activeLoans++;
        borrowerProfiles[msg.sender].totalBorrowed += principal;

        emit PublicLoanCreated(
            loanId,
            msg.sender,
            principal,
            interestRate,
            duration
        );
    }

    /*//////////////////////////////////////////////////////////////
                        FUND LOAN
    //////////////////////////////////////////////////////////////*/

    function fundLoan(uint256 loanId) external payable {

        Loan storage loan = loans[loanId];

        require(loan.status == LoanStatus.Requested, "Not fundable");

        require(msg.value == loan.principal, "Incorrect funding");

        loan.lender = msg.sender;
        loan.status = LoanStatus.Active;
        loan.startTime = block.timestamp;

        lenderLoans[msg.sender] = loanId;

        lenderPositions[msg.sender].totalLent += loan.principal;
        lenderPositions[msg.sender].activeLoans++;

        payable(loan.borrower).transfer(loan.principal);

        emit LoanFunded(loanId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        REPAY LOAN
    //////////////////////////////////////////////////////////////*/

    function repayLoan(uint256 loanId) external payable {

        Loan storage loan = loans[loanId];

        require(loan.status == LoanStatus.Active, "Loan inactive");
        require(msg.sender == loan.borrower, "Not borrower");

        uint256 interest = _interest(loan.principal, loan.interestRate);
        uint256 totalOwed = loan.principal + interest;

        require(msg.value >= totalOwed, "Insufficient repayment");

        loan.amountRepaid = msg.value;
        loan.status = LoanStatus.Repaid;

        borrowerLoans[msg.sender] = 0;

        borrowerProfiles[msg.sender].repaidLoans++;

        lenderPositions[loan.lender].activeLoans--;

        payable(loan.lender).transfer(totalOwed);

        _transferCollateralOut(
            loan.collateral.token,
            loan.borrower,
            loan.collateral.amount
        );

        emit LoanRepaid(loanId);
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDATE LOAN
    //////////////////////////////////////////////////////////////*/

    function liquidateLoan(uint256 loanId) external {

        Loan storage loan = loans[loanId];

        require(loan.status == LoanStatus.Active, "Loan inactive");

        require(
            block.timestamp > loan.startTime + loan.duration,
            "Loan not expired"
        );

        loan.status = LoanStatus.Liquidated;

        borrowerLoans[loan.borrower] = 0;

        lenderPositions[loan.lender].activeLoans--;

        _transferCollateralOut(
            loan.collateral.token,
            loan.lender,
            loan.collateral.amount
        );

        emit LoanLiquidated(loanId);
    }

    /*//////////////////////////////////////////////////////////////
                        CANCEL LOAN
    //////////////////////////////////////////////////////////////*/

    function cancelLoan(uint256 loanId) external {

        Loan storage loan = loans[loanId];

        require(loan.status == LoanStatus.Requested, "Cannot cancel");
        require(msg.sender == loan.borrower, "Not borrower");

        loan.status = LoanStatus.Cancelled;

        borrowerLoans[msg.sender] = 0;

        borrowerProfiles[msg.sender].activeLoans--;

        _transferCollateralOut(
            loan.collateral.token,
            loan.borrower,
            loan.collateral.amount
        );

        emit LoanCancelled(loanId);
    }

    receive() external payable {}
}