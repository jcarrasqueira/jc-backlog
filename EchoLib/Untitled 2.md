# **1. Preconditions**

You must have:

- **1 DEX** in your wallet
    
- Contract funded with ETH
    
- Contract deployed with:
    

Code

```
dexSwapRate   = 100
paymentCycle  = 30
interest      = 10
termination   = 50
```

# ✅ **2. Create the loan**

Call:

Code

```
loan(1, 3)
```

This means:

- Collateral = **1 DEX**
    
- Swap rate = **100 wei**
    
- Collateral value = `1 * 100 = 100 wei`
    
- Borrow limit = 50% → `100 / 2 = 50 wei`
    

So:

### **Loan principal = 50 wei**

# ✅ **3. Compute the payment amounts**

### **Interest per cycle**

Formula from spec:

Code

```
cyclePayment = amount * interest / deadline
```

Plug in:

Code

```
cyclePayment = 50 * 10 / 3
             = 500 / 3
             = 166 wei  (integer division)
```

So:

- **Payment 1 = 166 wei**
    
- **Payment 2 = 166 wei**
    

### **Final payment includes principal**

Your code:

solidity

```
if (cyclesPaid == deadline - 1) {
    requiredAmount += currentLoan.amount;
}
```

So:

Code

```
finalPayment = 166 + 50 = 216 wei
```

# ⭐ **4. The EXACT values you must use in Remix**

Here is your full 3‑payment schedule:

|Payment #|cyclesPaid before call|Required msg.value|Why|
|---|---|---|---|
|**1**|0|**166 wei**|interest only|
|**2**|1|**166 wei**|interest only|
|**3**|2|**216 wei**|interest + principal|

# ⭐ **5. The EXACT Remix calls**

## 🔵 **Payment 1 (within 30 seconds)**

Code

```
makePayment(1)
value: 166
```

Expected:

- cyclesPaid = 1
    
- nextPayment += 30 seconds
    

## ⏳ Wait 30 seconds

## 🔵 **Payment 2**

Code

```
makePayment(1)
value: 166
```

Expected:

- cyclesPaid = 2
    
- nextPayment += 30 seconds
    

## ⏳ Wait 30 seconds

## 🔵 **Payment 3 (final)**

Code

```
makePayment(1)
value: 216
```