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
    
    mapping(uint256 => bool) public active;              // whether loan is active or not
    mapping(uint256 => uint256) public startTime;        // time loan started
    mapping(uint256 => uint256) public nextPayment;      // timestamp when next interest payment is due
    mapping(uint256 => uint256) public paymentAmount;    // interest payment owed each cycle (in wei)
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

    modifier onlyOwner() {
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

    function loan(uint256 dexAmount, uint256 deadline) external returns(uint256 loanID){
        require(dexAmount > 0, "No DEX sent"); // checks collateral
        require(balanceOf(msg.sender) >= dexAmount , "Client doesn't own enough DEX for this loan."); // checks user balance
        require(deadline > 0 && deadline <= maxLoanDuration, "Invalid deadline"); // checks for deadline

        // computes and validates collateral amount (eth)
        uint256 collateralEth = dexAmount * dexSwapRate; 
        uint256 loanAmount = collateralEth / 2; // only 50% can be borrowed
        uint256 interestPerCycle = (loanAmount * interest) / deadline;

        require(address(this).balance >= loanAmount, "Contract doesn't have enough ETH"); // checks if amount in contract is enough for loan
        require(interestPerCycle > 0, "Interest per cycle too small"); // since 0 interest can break the loan cycle
        
        _transfer(msg.sender, address(this), dexAmount);

        loanID = nextLoanID;
        nextLoanID++;
        
        loans[loanID] = Loan(msg.sender, dexAmount, loanAmount, deadline); // loan mapping

        // auxiliary mappings
        nextPayment[loanID] = block.timestamp + paymentCycle;
        paymentAmount[loanID] = interestPerCycle;
        startTime[loanID] = block.timestamp;
        active[loanID] = true;
        cyclesPaid[loanID] = 0;
        
        emit loanCreated(msg.sender, loanAmount, deadline); //event emission
        
        return loanID;
    }

    function makePayment(uint256 loanId) external payable  {
        Loan current_loan = loans[loanId];
        require(!ln.isBasedNft, "Should not be nft loan");
        require(ln.amount > 0, "Loan is not active");
        //require(msg.sender == ln.borrower, "Not your loan to pay");
        require(cyclesPaid[loanId] < totalCycles[loanId], "All cycles already paid");
        require(block.timestamp <= ln.deadline, "Loan past deadline");

        uint256 dueTime = nextPayment[loanId];
        //require(block.timestamp >= dueTime, "Too early for this payment");
        uint256 dueAmount = paymentAmount[loanId];
        require(msg.value == dueAmount, "Incorrect interest payment amount");

        cyclesPaid[loanId] += 1;

        if (cyclesPaid[loanId] < totalCycles[loanId]) {
            nextPayment[loanId] = dueTime + periodicity;
        }
    }

    function checkLoan(uint256 loanId) external  onlyOwner returns (Loan memory) {
        require(loans[loanId].borrower != address(0), "Loan does not exist");

        uint256 paymentDeadline = startTime[loanId] + (loans[loanId].deadline * paymentCycle);

        if(block.timestamp > paymentDeadline && active[loanId]){
            Loan memory expiredLoan = loans[loanId];

           delete loans[loanId];

           delete active[loanId];
           delete startTime[loanId];
           delete nextPayment[loanId];
           delete paymentAmount[loanId];
           delete cyclesPaid[loanId];

            return expiredLoan;

        }else{
            return loans[loanId];
        }
    }

    function getBalance() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function getDexBalance() external view returns (uint256) {
        return balanceOf(msg.sender);
    }

    function checkLoan(uint256 loanId) external view onlyOwner returns (Loan memory) {
        require(loans[loanId].borrower != address(0), "Loan does not exist");
        return loans[loanId];
    }
    
   
}