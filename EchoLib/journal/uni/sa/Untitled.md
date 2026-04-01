### 1. Describe your overall system design

Describe the binary structure, in order:
- **Header:**
    - **Salt (16 bytes):** random, used for key derivation.
    - **Initial MAC value (16 bytes):** e.g., all zeros or a fixed IV for the MAC chain.
        
- **Per entry:**
    - **IV (16 bytes):** random per entry (`os.urandom(16)`).
    - **Ciphertext length (4 bytes, big‑endian).**
    - **Ciphertext (length bytes):** AES‑CTR over TLV plaintext.
    - **MAC (16 bytes):** MAC over `(prev_mac || iv || length || ciphertext)`.

Explain that `verify_chain`:
- recomputes the MAC chain from the start,
- compares each stored MAC,
- aborts on any mismatch → `integrity violation`.
    

**b) TLV plaintext format**
Explain your TLV:
- **Tag (1 byte):** one of `FIELD_TIMESTAMP`, `FIELD_ROLE`, `FIELD_EVENT`, `FIELD_ROOM`, `FIELD_NAME`, `FIELD_UID`
- **Length (2 bytes, big‑endian).**
- **Value (length bytes).**

Then list fields:
- `FIELD_TIMESTAMP`: `uint32_be`
- `FIELD_ROLE`: `"employee"` / `"guest"` (UTF‑8)
- `FIELD_EVENT`: `"arrival"` / `"leave"` (UTF‑8)
- `FIELD_ROOM`: `uint32_be`
- `FIELD_NAME`: UTF‑8 string
- `FIELD_UID`: 16/32 bytes (output of `get_uid`)

**c) Identity model**
Explain:
- UID = `HMAC(k_uid, role || ":" || name)` (or whatever you used).
- This lets you distinguish:
    - employee Alex vs guest Alex,
    - two different guests named Alex.
- All state is keyed by UID, not by name.

**d) State reconstruction**
Describe `format_log`:
- Input: list of parsed entries.
- Output:
    - `in_gallery: {uid → role}`
    - `room_history: {room → set(uid)}`
    - `user_history: {uid → [room1, room2, …]}`
    - `names: {uid → name}`

Explain how:
- gallery‑level arrival/leave update `in_gallery`,
- room‑level arrival/leave update `room_history` and `user_history`,
- `print_state` and `print_user_history` are pure views over this state.

### 2. Describe the security protocol
Summarize the crypto pipeline:

1. **Key derivation:**
    - Input: user token + salt.
    - KDF (e.g., HKDF/PBKDF2 or HMAC‑based split) → `k_encryption`, `k_mac`, maybe `k_uid`.

2. **Encryption:**
    - For each entry:
        - Generate `iv = os.urandom(16)`.
        - Encrypt TLV plaintext with AES‑CTR using `k_encryption` and `iv`.
3. **MAC chain:**
    - For each entry:
        - `mac_i = HMAC(k_mac, mac_{i-1} || iv || length || ciphertext)`.
    - Store `mac_i` after each entry.
4. **Verification:**
    - `verify_chain` recomputes the chain and aborts on mismatch.

Make explicit:
- **Confidentiality:** AES‑CTR with random IV.
- **Integrity & ordering:** MAC chain over all entries.
- **Identity binding:** UID derived from token‑bound key.

### 3. Performance discussion
Be concrete:
- **Asymptotic:**
    - `logappend`: O(1) per entry (append‑only, no full scan).
    - `logread`: O(n) over number of entries.
- **Implementation details:**
    - Single pass over file in `logread`.
    - TLV parsing is linear in entry size.
    - State reconstruction is linear in number of entries.
- **Trade‑offs:**
    - You chose a simple append‑only format (no indexing) → good enough for assignment scale, easy to reason about.
    - You could mention possible future optimizations (indexing by UID, room, etc.) as “would implement if needed”.

### 4. Four attacks and how you counter them
Pick clear, concrete ones and point to functions like `verify_chain`, `decrypt`, `get_uid`, `logappend`.
Examples:

1. **Attack:** Truncation or deletion of entries. **Mitigation:** MAC chain; any deletion breaks all subsequent MACs. **Code:** `verify_chain` and MAC computation in `logappend`.
2. **Attack:** Reordering entries. **Mitigation:** MAC chain binds each entry to the previous one; reordering breaks verification. **Code:** same as above.
3. **Attack:** Bit‑flipping in ciphertext (trying to change room, name, role). **Mitigation:** MAC covers ciphertext; any modification breaks MAC. **Code:** `verify_chain` before `decrypt`.
4. **Attack:** Impersonating another user with same name (e.g., guest Alex vs employee Alex). **Mitigation:** UID derived from token‑bound key and role; state keyed by UID, not name. **Code:** `get_uid`, use of `uid` in `format_log`.
    
You can also mention:
- **Attack:** Using wrong token to read/append. **Mitigation:** Wrong token → wrong keys → MAC verification fails → `integrity violation`.
    
### 5. Subtle vulnerability to introduce
You need something that:
- doesn’t instantly break everything,
- is realistic,
- is subtle enough that a casual reader might miss it,
- but you can explain clearly.

Some ideas:
- **Vulnerability:** You don’t check for duplicate timestamps or enforce strict monotonicity. **Impact:** An attacker who can append with the correct token could insert confusing entries with old timestamps that still verify but change the apparent history. **Why subtle:** MAC chain still passes; crypto is fine; but semantic ordering by timestamp can be abused.
- **Vulnerability:** You don’t validate that `room` is non‑zero and within a reasonable range. **Impact:** Attacker can create “ghost rooms” (e.g., room 0 or huge IDs) that might confuse downstream tools or analyses. **Why subtle:** Doesn’t break security, but breaks assumptions about state.
- **Vulnerability:** You treat missing fields leniently in `readble_entry` (e.g., assuming `name`, `role`, `uid` always present). **Impact:** A malformed but MAC‑valid entry could cause a `KeyError` or inconsistent state. **Why subtle:** Crypto is still correct; bug is in parsing assumptions.