# Structure of data
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
Flag | len | value
01 <len> <timestamp>
02 <len> <role>
03 <len> <event_type>
04 <len> <room>
05 <len> <name>
06 <len> <uid>
```

```
[TAG_TIMESTAMP][LEN][4 bytes]
[TAG_ROLE][LEN][string]
[TAG_EVENT][LEN][string]
[TAG_ROOM][LEN][4 bytes] (optional)
[TAG_NAME][LEN][string]
[TAG_USERID][LEN][8 bytes]
```

# Project explanation
## must haves
- [ ] libs used with links and for what they were used (maybe a table)
- [ ] remove comments from code


## Libs
### Struct
- Used for: packing and unpacking binary integers
#### why
- Your log format uses binary fields, not text.
- struct lets you convert between Python integers and fixed‑size byte sequences.

```
struct.pack("!I", n)     # 4‑byte unsigned integer, big‑endian
struct.unpack("!H", b)   # 2‑byte unsigned integer, big‑endian
```

| Notation | Meaning            | Size    | Used For                                          |
| -------- | ------------------ | ------- | ------------------------------------------------- |
| ``!``    | Network byte order | —       | Ensures consistent binary format                  |
| ``I``    | Unsigned int       | 4 bytes | Ciphertext length, counters, timestamps, room IDs |
| ``H``    | Unsigned short     | 2 bytes | TLV field lengths                                 |
| ``!I``   | Big‑endian uint32  | 4 bytes | ``[ ``4 ``bytes ``] ``LEN``                       |
| ``!H``   | Big‑endian uint16  | 2 bytes | ``[ ``2 ``bytes ``] ``LENGTH`` in TLV             |
### cryptography.hazmat.primitives.ciphers
- Used for: AES‑CTR encryption and decryption
```python
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
```

#### Why it’s needed
- `Cipher` constructs an encryption/decryption object.
- `algorithms.AES(key)` selects AES as the block cipher.
- `modes.CTR(iv)` selects CTR mode, which turns AES into a stream cipher.

#### Why CTR mode?
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
- You use it to build a MAC chain, which prevents:
	- log modification
	- entry deletion
	- entry reordering
	- entry insertion
- This aligns with the project requirement that an attacker must not be able to “modify the log… or fool logread into accepting a bogus file.”

### hashlib
- Used for: SHA‑256 inside HMAC
#### why
SHA‑256 is:
- secure
- widely used
- collision‑resistant
- appropriate for MAC chaining
You truncate the output to 16 bytes (128 bits), which is still secure for this context. -> so AES-128 can be used instead AES-256

# functions 
### readable_log