# Structure of data
## Log header
```
[16 bytes]  SALT
[16 bytes]  MAC_PREV
```

## Encrypted log entry
- len = length of ciphertext
```
[16 bytes]  IV
[ 4 bytes]  LEN
[LEN bytes] CIPHERTEXT
[16 bytes]  MAC
```

## entry (plaintext)
```
[1 byte]   FLAG
[2 bytes]  LENGTH
[LENGTH]   VALUE
```

```
[FLAG_TIMESTAMP][LEN][4 bytes]
[FLAG_ROLE][LEN][string]
[FLAG_EVENT][LEN][string]
[FLAG_ROOM][LEN][4 bytes] (optional)
[FLAG_NAME][LEN][string]
[FLAG_USERID][LEN][8 bytes]
```

# Project 
## Libs
### Struct
- Used for: packing and unpacking binary integers
#### why
- The log format uses binary fields, not text.
- struct allows to convert between Python integers and fixed‑size byte sequences.

```
struct.pack("!I", n)     # 4‑byte unsigned integer, big‑endian
struct.unpack("!H", b)   # 2‑byte unsigned integer, big‑endian
```

| Notation | Meaning            | Size    | Used For                                          |
| -------- | ------------------ | ------- | ------------------------------------------------- |
| ``!``    | Network byte order | —       | Ensures consistent binary format                  |
| ``I``    | Unsigned int       | 4 bytes | Ciphertext length, counters, timestamps, room IDs |
| ``H``    | Unsigned short     | 2 bytes | field lengths                                     |
| ``!I``   | Big‑endian uint32  | 4 bytes | `[ 4 bytes ] LEN`                                 |
| ``!H``   | Big‑endian uint16  | 2 bytes | `[ 2 bytes ] LEN`                                 |
### cryptography.hazmat.primitives.ciphers
- Used for: AES‑CTR encryption and decryption
```python
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
```

#### why
- `Cipher` constructs an encryption/decryption object.
- `algorithms.AES(key)` selects AES as the block cipher.
- `modes.CTR(iv)` selects CTR mode, which turns AES into a stream cipher.

#### why ctr mode
- No padding required
- Random access to ciphertext
- Perfect for logs where each entry is independent
- Fast and widely supported

This directly supports the project requirement that the system must _“guarantee the confidentiality… of the log”_.

### hmac
- Used for: Message Authentication Codes (MACs)
``` python
import hmac
```

#### why
- HMAC ensures integrity and tamper detection.
- A MAC chain is build, which prevents:
	- log modification
	- entry deletion
	- entry reordering
	- entry insertion
- This aligns with the project requirement that an attacker must not be able to *“modify the log… or fool logread into accepting a bogus file.”*

### hashlib
- Used for: SHA‑256 inside HMAC
#### why
SHA‑256 is:
- secure
- widely used
- collision‑resistant
- appropriate for MAC chaining
the output is truncated to 16 bytes (128 bits), which is still secure for this context -> so AES-128 can be used instead AES-256

# functions 

| Function           | Responsibility                                       |
| ------------------ | ---------------------------------------------------- |
| readble_entry      | Parse TLV plaintext into Python dict                 |
| logread            | Verify MAC chain, decrypt entries, parse log         |
| format_log         | Reconstruct gallery state + history                  |
| print_state        | Implement ``-S`` (current state)                     |
| print_user_history | Implement ``-R`` (room history)                      |
| main               | Argument parsing + calls print functions and logread |
