To thoroughly test your contract against the requirements in **dcb26-proj2.pdf**, use the following specific test values. These are designed to ensure your math (interest, 50% collateral, and swapping) works correctly without rounding errors.

### **1. Contract Deployment (Initial State)**

Deploy the contract with these parameters to make the math easy to verify:

- **`_dexSwapRate`**: `100000000000000` (0.0001 ETH per 1 DEX).
    
- **`_paymentCycle`**: `180` (3 minutes for testing).
    
- **`_interest`**: `10` (representing 10% per cycle).
    
- **`_termination`**: `5000000000000000` (0.005 ETH fixed fee).
    
- **Verification**: Check that `getDexBalance()` for the contract address is exactly $10^{18}$ (plus 18 decimals).
    

---

### **2. Token Swap Scenarios (`buyDex` & `sellDex`)**

- **Scenario A (Buying):** User sends **0.1 ETH**.
    
    - **Calculation**: $0.1 \text{ ETH} / 0.0001 \text{ rate} = 1000 \text{ DEX}$.
        
    - **Result**: User balance should be $1000 \times 10^{18}$ units. `balance` variable should increase by $10^{14}$ Wei.
        
- **Scenario B (Selling):** User sells **500 DEX**.
    
    - **Calculation**: $500 \text{ DEX} \times 0.0001 \text{ rate} = 0.05 \text{ ETH}$.
        
    - **Result**: User receives 0.05 ETH; `balance` variable decreases by 0.05 ETH.
        

---

### **3. The Loan Scenario (`loan`)**

- **Action**: User stakes **1000 DEX** for a **4-cycle** deadline.
    
    - **Collateral Value**: $1000 \text{ DEX} \times 0.0001 = 0.1 \text{ ETH}$.
        
    - **Max Loan (50%)**: $0.1 / 2 = 0.05 \text{ ETH}$ (50,000,000,000,000,000 Wei).
        
    - **Result**: User receives 0.05 ETH. `loans[loanId]` should show `amount: 0.05 ETH` and `collateral: 1000 DEX`.
        

---

### **4. Payment Scenarios (`makePayment`)**

Using the formula: $\text{cycle Payment} = (\text{amount} \times \text{interest}) / \text{deadline}$.

- **Scenario A (Interest Only - Cycles 1, 2, and 3):**
    
    - **Calculation**: $(0.05 \text{ ETH} \times 0.10) / 4 = 0.00125 \text{ ETH}$.
        
    - **Value to send**: `1250000000000000` Wei.
        
- **Scenario B (Final Payment - Cycle 4):**
    
    - **Calculation**: $\text{Interest} (0.00125) + \text{Principal} (0.05) = 0.05125 \text{ ETH}$.
        
    - **Value to send**: `51250000000000000` Wei.
        
    - **Result**: After this payment, `active[loanId]` should be `false` and the user's DEX balance should increase by 1000.
        

---

### **5. Early Termination (`terminateLoan`)**

- **Action**: User decides to end the loan immediately after cycle 1.
    
    - **Calculation**: $\text{Principal} (0.05 \text{ ETH}) + \text{Termination Fee} (0.005 \text{ ETH})$.
        
    - **Value to send**: `0.055 ETH` (55,000,000,000,000,000 Wei).
        
    - **Result**: Loan is closed; 1000 DEX returned to user.
        

---

### **6. Punishment Scenario (`checkLoan`)**

- **Action**: Wait > 3 minutes (the `paymentCycle`) without making a payment.
    
- **Owner Action**: Call `checkLoan(loanId)`.
    
- **Result**: The function should set `active[loanId] = false`. The user's 1000 DEX collateral is now "lost" (trapped in the contract).
    

---

### **Test Summary Table**

|**Function**|**Input Value**|**Expected ETH Change**|**Expected DEX Change**|
|---|---|---|---|
|**`buyDex`**|1 ETH|Contract `balance` +1 ETH|User +10,000 DEX|
|**`loan`**|1000 DEX|User +0.05 ETH|User -1000 DEX|
|**`makePayment`**|0.00125 ETH|Contract `balance` +0.00125|None|
|**`terminateLoan`**|0.055 ETH|Contract `balance` +0.055|User +1000 DEX|