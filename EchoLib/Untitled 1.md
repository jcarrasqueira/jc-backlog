### 1. Implementação (Deploy)

Insere estes 4 valores nos campos do Deploy (podes copiar e colar):

- `_dexSwapRate`: `100`
    
- `_paymentCycle`: `3600` (Isto dá-te 1 hora de prazo para cada pagamento)
    
- `_interest`: `10`
    
- `_termination`: `50`
    

---

### 2. Comprar Tokens (Preparação)

Antes de pedir um empréstimo, precisas de ter DEX.

- **Value (Remix)**: `10000`
    
- Clica em **buyDex**.
    
- _Check_: Clica em `getDexBalance`. Deve aparecer `100`.
    

---

### 3. Criar Empréstimo (`loan`)

- **Input `dexAmount`**: `100`
    
- **Input `deadline`**: `4`
    
- Clica em **transact**.
    
- _Resultado_: Recebes 5000 Wei. O teu `loanID` será **1**.
    

---

### 4. Fazer Pagamento (`makePayment`)

Vamos pagar o primeiro ciclo de juros.

- **Value (Remix)**: `125`
    
    - _(Cálculo: $5000 \times 10 / 400 = 125$)_
        
- **Input `loanID`**: `1`
    
- Clica em **transact**.
    
- _Check_: Se clicares no botão azul `cyclesPaid` com o número `1`, ele deve mostrar que já pagaste 1 ciclo.
    

---

### 5. Verificar Estado (`checkLoan`)

Esta função é apenas para o dono do contrato (Owner).

- **Input `loanID`**: `1`
    
- Clica em **call** (botão azul).
    
- _Resultado_: Deve aparecer a string **"Active"** e os detalhes do teu empréstimo (quem pediu, quanto colateral, etc).
    

---

### 6. Terminar Empréstimo (`terminateLoan`)

Vamos fechar o empréstimo pagando tudo de uma vez mais a taxa.

- **Value (Remix)**: `5050`
    
    - _(Cálculo: 5000 de capital + 50 de taxa de terminação)_
        
- **Input `loanID`**: `1`
    
- Clica em **transact**.
    
- _Resultado_: O teu `getDexBalance` volta a ser **100**. Se chamares o `checkLoan(1)` agora, o status será **"Terminated"**.