let provider;
let signer;
let contract;

const contractAddress = "0x17F827e99542eE2b81a273F6A119E5232D6C56b9";

const abi = [
    "function createLoan(uint256 interestRate,uint256 duration,uint256 penaltyPerSecond) payable returns (uint256)",
    "function takeLoan(uint256 loanId)",
    "function repayLoan(uint256 loanId) payable",
    "function getRepaymentAmount(uint256 loanId) view returns (uint256)",
    "function nextLoanId() view returns (uint256)"
];

async function connectWallet() {
    try {
        if (!window.ethereum) {
            throw new Error("MetaMask not detected");
        }

        if (!ethers.isAddress(contractAddress)) {
            throw new Error("Invalid contract address. Paste your deployed contract address in app.js.");
        }

        provider = new ethers.BrowserProvider(window.ethereum);
        await provider.send("eth_requestAccounts", []);

        signer = await provider.getSigner();
        const address = await signer.getAddress();
        const network = await provider.getNetwork();

        contract = new ethers.Contract(contractAddress, abi, signer);

        document.getElementById("wallet").innerText =
            `Connected: ${address}\nChain ID: ${network.chainId.toString()}`;

        setStatus("Wallet connected successfully.");
    } catch (err) {
        showError(err);
    }
}

async function createLoan() {
    try {
        ensureConnected();

        const interest = document.getElementById("interest").value.trim();
        const duration = document.getElementById("duration").value.trim();
        const penalty = document.getElementById("penalty").value.trim();
        const principal = document.getElementById("principal").value.trim();

        if (!interest || !duration || !penalty || !principal) {
            throw new Error("Please fill all fields.");
        }

        const tx = await contract.createLoan(
            BigInt(interest),
            BigInt(duration),
            BigInt(penalty),
            {
                value: ethers.parseEther(principal)
            }
        );

        setStatus("Creating loan...");
        await tx.wait();

        const nextId = await contract.nextLoanId();
        const createdId = Number(nextId) - 1;

        setStatus(`Loan created successfully. Loan ID: ${createdId}`);
    } catch (err) {
        showError(err);
    }
}

async function takeLoan() {
    try {
        ensureConnected();

        const loanId = document.getElementById("takeLoanId").value.trim();
        if (!loanId) throw new Error("Enter loan ID.");

        const tx = await contract.takeLoan(BigInt(loanId));
        setStatus("Taking loan...");
        await tx.wait();

        setStatus(`Loan ${loanId} taken successfully.`);
    } catch (err) {
        showError(err);
    }
}

async function checkRepayment() {
    try {
        ensureConnected();

        const loanId = document.getElementById("repayCheckId").value.trim();
        if (!loanId) throw new Error("Enter loan ID.");

        const amount = await contract.getRepaymentAmount(BigInt(loanId));
        document.getElementById("repaymentAmount").innerText =
            `Repayment Amount: ${ethers.formatEther(amount)} ETH`;

        setStatus("Repayment amount loaded.");
    } catch (err) {
        showError(err);
    }
}

async function repayLoan() {
    try {
        ensureConnected();

        const loanId = document.getElementById("repayLoanId").value.trim();
        const amount = document.getElementById("repayAmount").value.trim();

        if (!loanId || !amount) {
            throw new Error("Enter loan ID and repayment amount.");
        }

        const tx = await contract.repayLoan(BigInt(loanId), {
            value: ethers.parseEther(amount)
        });

        setStatus("Repaying loan...");
        await tx.wait();

        setStatus(`Loan ${loanId} repaid successfully.`);
    } catch (err) {
        showError(err);
    }
}

function ensureConnected() {
    if (!contract) {
        throw new Error("Connect wallet first.");
    }
}

function setStatus(message) {
    document.getElementById("status").innerText = message;
}

function showError(err) {
    console.error(err);
    document.getElementById("status").innerText =
        "Error: " + (err.reason || err.shortMessage || err.message || "Unknown error");
}