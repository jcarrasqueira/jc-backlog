# **Ideal Deployment Values (use these EXACT values)**

In Remix, deploy with:

Code

```
dexSwapRate      = 1000000000000      // 1e12 Wei
paymentCycle     = 60                 // 60 seconds
interest         = 10                 // 10%
terminationFee   = 1000000000000000   // 1e15 Wei = 0.001 ETH
maxLoanDuration  = 10                 // 10 cycles
```

And **Value = 0**.

# Expected Behavior With These Values

## ✔ BUY TEST

Send:

```
0.02 ETH = 20000000000000000 Wei
```

DEX received:

Code

```
DEX = ETH / dexSwapRate
    = 0.01 / 0.000001
    = 20,000 DEX
```

### Expected:

- User DEX = **10,000**
    
- Contract ETH = **0.01**
    
- Contract DEX = **10¹⁸ − 10,000**
    

## ✔ SELL TEST

Call:
```
sellDex(20001) # shuld mopt occur
```

```
sellDex(20000)
```

```
sellDex(10000)
```

ETH returned:

Code

```
ETH = 10000 * 0.000001 = 0.01 ETH
```

### Expected:

- User ETH +0.01
    
- User DEX = 0
    
- Contract ETH = 0
    
- Contract DEX = back to 10¹⁸
    

# ⭐ 4. **Loan Test With These Values**

Suppose user stakes **50,000 DEX**.

Loan amount:

Code

```
loanAmount = 50000 * 0.000001 ETH
           = 0.05 ETH
```

### Expected:

- User receives **0.05 ETH**
    
- Contract locks **50,000 DEX**
    
- Loan recorded correctly
    

# ⭐ 5. **Interest Payment Test**

Given:

- amount = 0.05 ETH
    
- interest = 10
    
- deadline = 5 cycles
    

Formula:

Code

```
cyclePayment = amount * interest / deadline
             = 0.05 * 10 / 5
             = 0.1 ETH / 5
             = 0.02 ETH
```

### Expected:

- User must send **0.02 ETH** per cycle
    

# ⭐ 6. **Termination Test**

User calls:

Code

```
terminateLoan(loanId)
```

User must pay:

Code

```
principal + terminationFee
= 0.05 ETH + 0.001 ETH
= 0.051 ETH
```

### Expected:

- User pays 0.051 ETH
    
- User gets 50,000 DEX back
    
- Loan is closed