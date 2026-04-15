// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/utils/Counters.sol"; not importing correctly

contract DecentralizedFinance is ERC20 {

    address private owner;
    uint256 private nextLoanID = 1;

    uint256 public balance; // balance of contract in Wei
    uint256 public paymentCycle; // payment cycle duration  == periocity
    uint256 public interest; // interest rate -> 10 = 10%
    uint256 public termination; // termination fee
    uint256 public maxLoanDuration = 10; // in cycles
    uint256 public dexSwapRate; // how many Wei a DEX costs
    
    struct Loan {
        address borrower; // adress of borrower
        uint256 collateral; // amount dex as collatera;
        uint256 amount; // loan amount in wei
        uint256 deadline; // deadline of loan, number of periods
        //uint256 startTime; // start of loan
        //uint256 paidCycles; // amount of cycles
        //bool active;
    }

    mapping(uint256 => Loan) public loans;
    mapping(uint256 => uint256) public nextPayment;      // timestamp when next interest payment is due
    mapping(uint256 => uint256) public paymentAmount;    // interest payment owed each cycle (in wei)
    mapping(uint256 => uint256) public cyclesPaid;       // how many cycles have been paid so far

    event loanCreated(address borrower, uint256 amount, uint256 deadline);

    constructor(uint256 _dexSwapRate, uint256 _paymentCycle, uint256 _interest, uint256 _termination) ERC20("DEX", "DEX") {
        owner = msg.sender;

        dexSwapRate = _dexSwapRate;
        paymentCycle = _paymentCycle;
        interest = _interest;
        termination = _termination;

        _mint(address(this), 10**18);
    }

    function buyDex() external payable {
        require(msg.value > 0, "No ETH sent");

        // amount of dex tokens user receives
        uint256 dexAmount = msg.value / dexSwapRate;
        require(dexAmount > 0, "Insufficient ETH to buy any DEX");

        // ensure contract has funds
        require(balanceOf(address(this)) >= dexAmount, "Contract does not have enough DEX in stock");

        // transfer dex amount to buyer
        _transfer(address(this), msg.sender, dexAmount);

        // Return any excess ETH
        uint256 cost = dexAmount * dexSwapRate;
        uint256 refund = msg.value - cost;

        if (refund > 0) {
            (bool success, ) = msg.sender.call{value: refund}("");
            require(success, "Refund failed");
        }
    }
    
    function sellDex(uint256 dexAmount) external { 
        require(dexAmount > 0, "Insufficient DEX to sell");
        require(balanceOf(msg.sender) >= dexAmount, "Insufficient funds (DEX)");

        // amount of eth for the user to receive
        uint256 ethAmount = dexAmount * dexSwapRate;
        require(address(this).balance >= ethAmount, "Contract does not have enough ETH");

        // transfer dex from user to contract
        _transfer(msg.sender, address(this), dexAmount);

        // pay in eth to user
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
    }

    function loan(uint256 dexAmount, uint256 deadline) external {
        require(dexAmount > 0, "No DEX sent"); // checks collateral
        require(balanceOf(msg.sender) >= dexAmount , "Client doesn't own enough DEX for this loan."); // checks user balance
        require(deadline > 0 && deadline <= maxLoanDuration, "Invalid deadline"); // checks for deadline

        // computes and validates collateral amount (eth)
        uint256 collateralEth = dexAmount * dexSwapRate; 
        uint256 loanAmount = collateralEth / 2; // only 50% can be borrowed

        require(address(this).balance >= loanAmount, "Contract doesn't have enough ETH"); // checks if amount in contract is enough for loan

        // later check if any cycle validation/calcs needed (interest per cycle)
        
        _transfer(msg.sender, address(this), dexAmount);

        Loan memory newLoan;
        newLoan.borrower = msg.sender;
        newLoan.collateral = dexAmount;
        newLoan.amount = loanAmount;
        newLoan.deadline = deadline;
        //newLoan.startTime = block.timestamp;
        //newLoan.paidCycles = 0;
        //newLoan.active = true;
        
        cyclePayment = loanAmount
        uint256 loanID = nextLoanID;
        nextLoanID++;

        nextPayment[loanID] = block.timestamp + paymentCycle;
        paymentAmount[loanID] = interestPerCycle;
        cyclesPaid[loanID] = 0;

        emit loanCreated(msg.sender, loanAmount, deadline);
        return loanID;

    }


    
    //TODO: implement the rest

}