// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DecentralizedFinance is ERC20 {
    address private owner;

    uint256 public balance; // balance of contract in Wei
    uint256 public paymentCycle; // payment cycle duration  == periocity
    uint256 public interest; // interest rate -> 10 = 10%
    uint256 public termination; // termination fee
    uint256 public maxLoanDuration = 10; // in cycles
    uint256 public dexSwapRate; // how many Wei a DEX costs
    
    uint256 public nextLoanId = 1;
   //nextLoanId++;

    struct Loan {
        address borrower;
        uint256 collateral; 
        uint256 amount;
        uint256 deadline; 
        uint256 startTime;
        uint256 paidCycles;
        bool active;
    }

    mapping(uint256 => Loan) public loans;

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

    //function loan(uint256 dexAmount, uint256 deadline) external {
        // TODO: implement this

    //}

    //TODO: implement the rest

}