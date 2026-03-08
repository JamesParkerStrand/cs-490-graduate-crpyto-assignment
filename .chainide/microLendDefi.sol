// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MicroLending {

    struct Loan {
        uint id;
        address borrower;
        uint amount;
        uint interest;
        uint duration;
        uint fundedAmount;
        uint startTime;
        bool funded;
        bool repaid;
    }

    uint public loanCounter;

    mapping(uint => Loan) public loans;
    mapping(uint => mapping(address => uint)) public lenders;

    event LoanRequested(uint loanId, address borrower, uint amount);
    event LoanFunded(uint loanId, address lender, uint amount);
    event LoanRepaid(uint loanId, uint totalAmount);

    // Borrower creates a loan request
    function requestLoan(
        uint _amount,
        uint _interest,
        uint _duration
    ) public {

        loanCounter++;

        loans[loanCounter] = Loan({
            id: loanCounter,
            borrower: msg.sender,
            amount: _amount,
            interest: _interest,
            duration: _duration,
            fundedAmount: 0,
            startTime: 0,
            funded: false,
            repaid: false
        });

        emit LoanRequested(loanCounter, msg.sender, _amount);
    }

    // Lenders fund a loan
    function fundLoan(uint _loanId) public payable {

        Loan storage loan = loans[_loanId];

        require(!loan.funded, "Already funded");
        require(msg.value > 0, "Send ETH");

        loan.fundedAmount += msg.value;
        lenders[_loanId][msg.sender] += msg.value;

        if (loan.fundedAmount >= loan.amount) {
            loan.funded = true;
            loan.startTime = block.timestamp;

            payable(loan.borrower).transfer(loan.amount);
        }

        emit LoanFunded(_loanId, msg.sender, msg.value);
    }

    // Borrower repays loan with interest
    function repayLoan(uint _loanId) public payable {

        Loan storage loan = loans[_loanId];

        require(msg.sender == loan.borrower, "Not borrower");
        require(loan.funded, "Loan not funded");
        require(!loan.repaid, "Already repaid");

        uint total = loan.amount + loan.interest;

        require(msg.value >= total, "Insufficient repayment");

        loan.repaid = true;

        emit LoanRepaid(_loanId, msg.value);
    }

    // Lenders withdraw their repayment share
    function withdraw(uint _loanId) public {

        Loan storage loan = loans[_loanId];

        require(loan.repaid, "Loan not repaid");

        uint contribution = lenders[_loanId][msg.sender];

        require(contribution > 0, "No funds");

        uint payout = contribution +
            (contribution * loan.interest) / loan.amount;

        lenders[_loanId][msg.sender] = 0;

        payable(msg.sender).transfer(payout);
    }
}