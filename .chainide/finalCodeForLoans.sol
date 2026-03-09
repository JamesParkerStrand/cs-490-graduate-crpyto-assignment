// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TimedLending {

    struct Loan {
        uint256 id;
        address payable lender;
        address payable borrower;
        uint256 principal;
        uint256 interestRate; // percent (ex: 10 = 10%)
        uint256 duration; // seconds
        uint256 startTime;
        uint256 dueTime;
        uint256 penaltyPerSecond; // wei penalty per second late
        bool taken;
        bool repaid;
    }

    uint256 public nextLoanId;

    mapping(uint256 => Loan) public loans;

    // Lender creates loan offer with ETH
    function createLoan(
        uint256 interestRate,
        uint256 duration,
        uint256 penaltyPerSecond
    ) external payable returns (uint256) {

        require(msg.value > 0, "Must fund loan");

        uint256 loanId = nextLoanId;

        loans[loanId] = Loan({
            id: loanId,
            lender: payable(msg.sender),
            borrower: payable(address(0)),
            principal: msg.value,
            interestRate: interestRate,
            duration: duration,
            startTime: 0,
            dueTime: 0,
            penaltyPerSecond: penaltyPerSecond,
            taken: false,
            repaid: false
        });

        nextLoanId++;

        return loanId;
    }

    // Borrower accepts loan
    function takeLoan(uint256 loanId) external {

        Loan storage loan = loans[loanId];

        require(!loan.taken, "Loan already taken");

        loan.borrower = payable(msg.sender);
        loan.taken = true;

        loan.startTime = block.timestamp;
        loan.dueTime = block.timestamp + loan.duration;

        loan.borrower.transfer(loan.principal);
    }

    // Calculate repayment amount
    function getRepaymentAmount(uint256 loanId) public view returns (uint256) {

        Loan storage loan = loans[loanId];

        uint256 interest = (loan.principal * loan.interestRate) / 100;
        uint256 total = loan.principal + interest;

        if(block.timestamp > loan.dueTime){
            uint256 lateTime = block.timestamp - loan.dueTime;
            uint256 penalty = lateTime * loan.penaltyPerSecond;
            total += penalty;
        }

        return total;
    }

    // Borrower repays loan
    function repayLoan(uint256 loanId) external payable {

        Loan storage loan = loans[loanId];

        require(msg.sender == loan.borrower, "Not borrower");
        require(!loan.repaid, "Already repaid");

        uint256 amountOwed = getRepaymentAmount(loanId);

        require(msg.value >= amountOwed, "Not enough repayment");

        loan.repaid = true;

        loan.lender.transfer(amountOwed);

        // return extra ETH if overpaid
        if(msg.value > amountOwed){
            payable(msg.sender).transfer(msg.value - amountOwed);
        }
    }

}