Great — let’s lock in **loan()** testing with the same clarity and precision we used for buy/sell. I’ll give you **exact values**, **expected results**, and **how to verify everything in Remix** using multiple accounts.

Everything below is aligned with your PDF requirements.

# ⭐ 1. Preconditions (so loan() works correctly)

Before a user can take a loan, they must:

1. **Own DEX tokens**
    
2. **Approve the contract** to transfer those DEX
    
3. **Call loan(dexAmount, deadline)**
    

Your contract will then:

- Lock the DEX as collateral
    
- Send ETH to the user
    
- Create a loan entry
    
- Emit `loanCreated`
    

# ⭐ 2. Test Setup (using the recommended swap rate)

You deployed with:

Code

```
dexSwapRate = 1e12 Wei  // 1 DEX = 0.000001 ETH
```

This makes the math clean.

# ⭐ 3. Step‑by‑Step Loan Test (Account 2)

Switch to **Account 2** in Remix.

## ✔ Step 1 — Buy DEX

Send:

Code

```
Value = 10000000000000000   // 0.01 ETH
```

Call:

Code

```
buyDex()
```

Expected:

Code

```
DEX received = 0.01 / 0.000001 = 10,000 DEX
```

Verify:

Code

```
balanceOf(Account2) = 10000 DEX
```

## ✔ Step 2 — Approve the contract to use your DEX

Call:

Code

```
approve(contractAddress, 10000)
```

Expected:

Code

```
allowance(Account2 → contract) = 10000
```

## ✔ Step 3 — Take a loan

Call:

Code

```
loan(5000, 5)
```

Meaning:

- Stake **5000 DEX** as collateral
    
- Deadline = **5 cycles**
    

### Expected loan amount:

Code

```
loanAmount = 5000 DEX × 0.000001 ETH
           = 0.005 ETH
```

In Wei:

Code

```
0.005 ETH = 5000000000000000 Wei
```

### Expected results:

|Item|Expected|
|---|---|
|Account2 ETH|**+0.005 ETH**|
|Account2 DEX|**10000 − 5000 = 5000 DEX**|
|Contract DEX|**+5000 DEX** (locked collateral)|
|Contract ETH|**−0.005 ETH**|
|loans[loanId].borrower|Account2|
|loans[loanId].collateral|5000|
|loans[loanId].amount|5000000000000000|
|loans[loanId].deadline|5|
|Event|`loanCreated(Account2, 5000000000000000, 5)`|

Everything should match exactly.

# ⭐ 4. Step‑by‑Step Loan Test (Account 3)

Switch to **Account 3**.

## ✔ Step 1 — Buy DEX

Send:

Code

```
Value = 5000000000000000   // 0.005 ETH
```

Call:

Code

```
buyDex()
```

Expected:

Code

```
DEX = 0.005 / 0.000001 = 5000 DEX
```

## ✔ Step 2 — Approve

Code

```
approve(contractAddress, 5000)
```

## ✔ Step 3 — Take a loan

Code

```
loan(3000, 3)
```

Expected:

Code

```
loanAmount = 3000 × 0.000001 = 0.003 ETH
```

# ⭐ 5. Verify loan math (interest payments)

The PDF gives the formula:

Code

```
cyclePayment = amount × interest / deadline
```

### For Account 2:

Code

```
amount = 0.005 ETH
interest = 10
deadline = 5

cyclePayment = 0.005 × 10 / 5
             = 0.01 / 5
             = 0.002 ETH
```

In Wei:

Code

```
0.002 ETH = 2000000000000000 Wei
```

So Account2 must send **0.002 ETH** each cycle.

# ⭐ 6. makePayment() test

Switch to Account 2.

Set:

Code

```
Value = 2000000000000000   // 0.002 ETH
```

Call:

Code

```
makePayment(loanId)
```

Expected:

- Payment recorded
    
- No collateral released yet
    
- Loan still active
    

# ⭐ 7. terminateLoan() test

Switch to Account 2.

User must pay:

Code

```
principal + terminationFee
= 0.005 ETH + 0.001 ETH
= 0.006 ETH
```

In Wei:

Code

```
6000000000000000
```

Set:

Code

```
Value = 6000000000000000
```

Call:

Code

```
terminateLoan(loanId)
```

Expected:

|Item|Expected|
|---|---|
|Account2 DEX|**gets 5000 DEX back**|
|Contract DEX|**loses 5000 DEX**|
|Contract ETH|**+0.006 ETH**|
|Loan removed|Yes|
|Event|`loanFinished(Account2, 5000000000000000)`|

# ⭐ 8. checkLoan() test (owner only)

Switch back to **Account 1** (deployer).

Call:

Code

```
checkLoan(loanId)
```

Expected behavior:

- If deadline passed → collateral seized
    
- If payments missing → collateral seized
    
- If fully paid → nothing happens
    

# ⭐ Final Summary (what you should see)

### After Account 2 takes a loan:

- Account2 ETH increases by **0.005 ETH**
    
- Account2 DEX decreases by **5000**
    
- Contract ETH decreases by **0.005 ETH**
    
- Contract DEX increases by **5000**
    
- Loan entry created
    

### After Account 2 makes a payment:

- Contract ETH increases by **0.002 ETH**
    

### After Account 2 terminates the loan:

- Account2 pays **0.006 ETH**
    
- Account2 gets **5000 DEX** back
    
- Loan entry removed
    

Everything matches the PDF requirements.