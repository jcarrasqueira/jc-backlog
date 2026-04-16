// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DecentralizedFinance is ERC20 {
    address private owner;
    uint256 private nextLoanID = 1; // serves as a counter for loan ids
    uint256 private balance; // balance of contract in wei
    
    uint256 public paymentCycle; // payment cycle duration  == periocity
    uint256 public interest; // interest rate
    uint256 public termination; // termination fee
    uint256 public maxLoanDuration = 10; // in cycles 
    uint256 public dexSwapRate; // how many Wei a DEX costs
    
    struct Loan {
        address borrower; // adress of borrower
        uint256 collateral; // amount dex as collateral
        uint256 amount; // loan amount in wei
        uint256 deadline; // deadline of loan, number of periods
    }

    mapping(uint256 => Loan) public loans;               // loan mapping
    mapping(uint256 => bool) public active;              // whether loan is active or not
    mapping(uint256 => uint256) public nextPayment;      // timestamp when next interest payment is due
    mapping(uint256 => uint256) public cyclesPaid;       // how many cycles have been paid so far

    event loanCreated(address borrower, uint256 amount, uint256 deadline);
    event loanFinished(address borrower, uint256 amount);

    constructor(uint256 _dexSwapRate, uint256 _paymentCycle, uint256 _interest, uint256 _termination) ERC20("DEX", "DEX") {
        owner = msg.sender;
        
        dexSwapRate = _dexSwapRate;
        paymentCycle = _paymentCycle;
        interest = _interest;
        termination = _termination;

        _mint(address(this), 10**18);
    }

    modifier onlyOwner() { // helper to limit access to owner fuctions (checkLoan and getBalance)
        require(msg.sender == owner, "Only contract owner can call this function.");
        _;
    }

    function buyDex() external payable {
        require(msg.value > 0, "No ETH sent");

        // amount of dex tokens user receives
        uint256 dexAmount = msg.value / dexSwapRate;
        require(dexAmount > 0, "Insufficient ETH to buy any DEX");

        // ensure contract has funds
        require(balanceOf(address(this)) >= dexAmount, "Contract does not have enough DEX in stock");

        // update balance
        uint256 cost = dexAmount * dexSwapRate;
        balance += cost;

        // transfer dex amount to buyer
        _transfer(address(this), msg.sender, dexAmount);

        // Return any excess ETH
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

        balance -= ethAmount; // updated balance
        
        // pay in eth to user
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
    }

    function loan(uint256 dexAmount, uint256 deadline) external returns(uint256 loanID){
        require(dexAmount > 0, "No DEX sent"); // checks collateral dex
        require(balanceOf(msg.sender) >= dexAmount , "Client doesn't own enough DEX for this loan."); // checks user balance
        require(deadline > 0 && deadline <= maxLoanDuration, "Invalid deadline"); // checks for deadline

        // computes and validates collateral amount (eth)
        uint256 collateralEth = dexAmount * dexSwapRate; 
        uint256 loanAmount = collateralEth / 2; // only 50% can be borrowed 
        require(address(this).balance >= loanAmount, "Contract doesn't have enough ETH"); // checks if amount in contract is enough for loan
        
        // sends collateral to contract
        _transfer(msg.sender, address(this), dexAmount);

        loanID = nextLoanID;
        nextLoanID++;
        
        loans[loanID] = Loan(msg.sender, dexAmount, loanAmount, deadline); // loan mapping

        // auxiliary mappings
        nextPayment[loanID] = block.timestamp + paymentCycle;
        active[loanID] = true;
        cyclesPaid[loanID] = 0;

        balance -= loanAmount; //update balance

        // tranfer loan amount to borrower
        (bool success, ) = msg.sender.call{value: loanAmount}(""); 
        require(success, "ETH transfer failed");

        emit loanCreated(msg.sender, loanAmount, deadline); //event emission
        return loanID;
    }

    function makePayment(uint256 loanID) external payable {
        Loan storage currentLoan = loans[loanID];

        require(currentLoan.borrower != address(0), "Loan does not exist");
        require(active[loanID], "Loan is not active");
        require(msg.sender == currentLoan.borrower, "Only borrower can pay");
        require(block.timestamp <= nextPayment[loanID], "Payment deadline passed");

        // cycle Payment = amount x interest / deadline
        uint256 duePayment = (currentLoan.amount * interest) / currentLoan.deadline;
        uint256 requiredAmount = duePayment;
        
        if(cyclesPaid[loanID] == currentLoan.deadline - 1){ // last payment must send principal
            requiredAmount += currentLoan.amount;
        }

        require(msg.value == requiredAmount, "Incorrect payment amount");
       
        balance += requiredAmount;       
        cyclesPaid[loanID]++;

        if (cyclesPaid[loanID] == loans[loanID].deadline) { //sucessfull loan payment
            active[loanID] = false;
            _transfer(address(this), currentLoan.borrower, currentLoan.collateral); // send collateral back
            emit loanFinished(currentLoan.borrower, currentLoan.amount);
        } 
        else { // next payment cycle
            nextPayment[loanID] += paymentCycle;
        }
    }

    function terminateLoan(uint256 loanID) external payable { 
        Loan storage currentLoan = loans[loanID];
        require(currentLoan.borrower != address(0), "Loan does not exist");
        require(active[loanID], "Loan is not active");
        require(msg.sender == currentLoan.borrower, "Only borrower can terminate");

        // in order to terminate user must pay the value of termination fee
        uint256 totalDue = currentLoan.amount + termination; 
        require(msg.value >= totalDue, "Insufficient repayment");
        
        balance += totalDue;
        active[loanID] = false;
        
        // Return the DEX collateral to the user
        _transfer(address(this), msg.sender, currentLoan.collateral);

        uint256 excess = msg.value - totalDue; // in case value sent is superior to value needed returns the rest
        if (excess > 0) {
            (bool success, ) = payable(msg.sender).call{value: excess}("");
            require(success, "Refund failed");
        }

        emit loanFinished(msg.sender, currentLoan.amount);
    }

    // state of loan is considered as a status message, the deadline of the loan and the amount of cycles that have been payed
    // status can be Terminated - Collateral Lost, Terminated or Active
    function checkLoan(uint256 loanID) external onlyOwner returns (string memory status,uint256 deadline,uint256 cycles){
        require(loans[loanID].borrower != address(0), "Loan does not exist");

        if (block.timestamp > nextPayment[loanID] && active[loanID]) { // when loan is not payed on time
            // this ensures the collateral can't be recovered since if active == false no other loan operations can occur
            active[loanID] = false; 
            status = "Terminated - Collateral Lost";
        } else if (active[loanID]) {
            status = "Active";
        } else {
            status = "Terminated";
        }

        deadline = loans[loanID].deadline;
        cycles = cyclesPaid[loanID];
    }

    function getBalance() external view onlyOwner returns (uint256) { // returns balance of contract in wei
        return balance;
    }

    function getDexBalance() external view returns (uint256) { // returns dex balance of user
        return balanceOf(msg.sender);
    }  
}