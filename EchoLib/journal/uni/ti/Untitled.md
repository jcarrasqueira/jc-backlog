# Step‑by‑step: Testing with multiple users

### 1. Deploy the contract

Choose **Account #1** in Remix.

Deploy with:

Code

```
dexSwapRate = 1000000000000000
paymentCycle = 60
interest = 10
terminationFee = 1000000000000000
maxLoanDuration = 10
```

Now **Account #1 is the owner**.

# ⭐ 2. Switch users in Remix

At the top of Remix, you have:

Code

```
ACCOUNT: 0x5B3...eddC4  ▼
```

Click the dropdown and select:

- Account #2
    
- Account #3
    
- Account #4
    
- etc.
    

Each one is a **different user**.

# ⭐ 3. Test buyDex() as different users

### User 2 buys DEX

- Switch to **Account #2**
    
- Set Value = `10000000000000000` (0.01 ETH)
    
- Call `buyDex()`
    

Expected:

Code

```
User2 DEX = 10
Contract ETH = 0.01
```

### User 3 buys DEX

- Switch to **Account #3**
    
- Set Value = `5000000000000000` (0.005 ETH)
    
- Call `buyDex()`
    

Expected:

Code

```
User3 DEX = 5
Contract ETH = 0.015
```

# ⭐ 4. Test sellDex() as different users

### User 2 sells 10 DEX

- Switch to **Account #2**
    
- Call `sellDex(10)`
    

Expected:

Code

```
User2 ETH +0.01
User2 DEX = 0
Contract ETH = 0.005
```

### User 3 sells 5 DEX

- Switch to **Account #3**
    
- Call `sellDex(5)`
    

Expected:

Code

```
User3 ETH +0.005
User3 DEX = 0
Contract ETH = 0
```

# ⭐ 5. Test loan() as different users

### User 2 takes a loan

- Switch to **Account #2**
    
- Stake 10 DEX
    
- Choose deadline = 5 cycles
    
- Call `loan(10, 5)`
    

Expected:

Code

```
Loan amount = 10 * dexSwapRate = 0.01 ETH
User2 ETH +0.01
Collateral locked = 10 DEX
```

### User 3 takes a loan

- Switch to **Account #3**
    
- Stake 5 DEX
    
- Deadline = 3 cycles
    
- Call `loan(5, 3)`
    

Expected:

Code

```
Loan amount = 5 * dexSwapRate = 0.005 ETH
User3 ETH +0.005
Collateral locked = 5 DEX
```

# ⭐ 6. Test makePayment() as different users

Switch to each user and call:

Code

```
makePayment(loanId)
```

Expected:

Code

```
cyclePayment = amount * interest / deadline
```

Example for User2:

Code

```
amount = 0.01 ETH
interest = 10%
deadline = 5 cycles

cyclePayment = 0.01 * 10 / 5 = 0.002 ETH
```

# ⭐ 7. Test terminateLoan() as different users

Switch to the user who owns the loan and call:

Code

```
terminateLoan(loanId)
```

Expected:

- User pays back principal + termination fee
    
- User gets DEX collateral back
    

# ⭐ 8. Test checkLoan() as the owner

Switch back to **Account #1** (owner).

Call:

Code

```
checkLoan(loanId)
```

Expected:

- If deadline passed → collateral seized
    
- If payments missing → collateral seized
    
- If fully paid → nothing happens