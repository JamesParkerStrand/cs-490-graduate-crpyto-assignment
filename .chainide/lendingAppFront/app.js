let provider;
let signer;
let contract;

const contractAddress = "YOUR_CONTRACT_ADDRESS";

const abi = [
    "function createLoan(uint256 interestRate,uint256 duration,uint256 penaltyPerSecond) payable returns(uint256)",
    "function takeLoan(uint256 loanId)",
    "function repayLoan(uint256 loanId) payable",
    "function getRepaymentAmount(uint256 loanId) view returns(uint256)"
];

async function connectWallet() {

    if (!window.ethereum) {
        alert("Install MetaMask");
        return;
    }

    provider = new ethers.BrowserProvider(window.ethereum);

    await provider.send("eth_requestAccounts", []);

    signer = await provider.getSigner();

    contract = new ethers.Contract(contractAddress, abi, signer);

    const address = await signer.getAddress();

    document.getElementById("wallet").innerText = "Connected: " + address;
}

async function createLoan() {

    const interest = document.getElementById("interest").value;
    const duration = document.getElementById("duration").value;
    const penalty = document.getElementById("penalty").value;
    const principal = document.getElementById("principal").value;

    const tx = await contract.createLoan(
        interest,
        duration,
        penalty,
        {
            value: ethers.parseEther(principal)
        }
    );

    await tx.wait();

    alert("Loan Created!");
}

async function takeLoan() {

    const loanId = document.getElementById("takeLoanId").value;

    const tx = await contract.takeLoan(loanId);

    await tx.wait();

    alert("Loan Taken!");
}

async function checkRepayment() {

    const loanId = document.getElementById("repayCheckId").value;

    const amount = await contract.getRepaymentAmount(loanId);

    const eth = ethers.formatEther(amount);

    document.getElementById("repaymentAmount").innerText =
        "Repayment Amount: " + eth + " ETH";
}

async function repayLoan() {

    const loanId = document.getElementById("repayLoanId").value;
    const amount = document.getElementById("repayAmount").value;

    const tx = await contract.repayLoan(
        loanId,
        {
            value: ethers.parseEther(amount)
        }
    );

    await tx.wait();

    alert("Loan Repaid!");
}