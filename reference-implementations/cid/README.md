# koad.generate.cid — Reference Implementations

Spec: [VESTA-SPEC-027](../VESTA-SPEC-027-cid-privacy-primitive.md)

## Canonical Test Vectors

All implementations must produce identical output for these inputs:

| Function | Input | Output |
|---|---|---|
| `handle` | `"https://github.com/koad"` | `"httpsgithubcomkoad"` |
| `cid` | `"httpsgithubcomkoad"` | `"GdYZWjcjY6Y2XonnM"` |
| `cid` | `"koad"` | `"TysPFWq8Nr5LZQQnM"` |
| `cid` | `""` | `"9DbDncYNpbSfo3Ngj"` |

## Algorithm

```
CHARSET = "23456789ABCDEFGHJKLMNPQRSTWXYZabcdefghijkmnopqrstuvwxyz"  # 55 chars
CID_LEN = 17

handle(str):
    return str.lower().replace(/[^a-z0-9]/g, "")

cid(str):
    h      = handle(str)
    digest = SHA256(h.encode("utf-8"))     # raw bytes
    result = ""
    for i in 0..CID_LEN:
        result += CHARSET[digest[i] % 55]
    return result
```

**Note:** `digest[i] % 55` introduces minor modulo bias (256 % 55 = 36; values 0–35 appear ~1/7 more often than 36–54). This is documented in VESTA-SPEC-027 as a known statistical impurity — not a security issue at current scale. Do not "fix" it in implementations; all implementations must match the JS canonical behavior exactly.

## Implementations

| File | Language | Dependency |
|---|---|---|
| `cid.sh` | Bash | `sha256sum` or `openssl` |
| `cid.py` | Python 3.6+ | stdlib (`hashlib`, `re`) |
| `cid.go` | Go | stdlib (`crypto/sha256`) |
| `cid.rs` | Rust | `sha2 = "0.10"` |
| `cid.c` | C | OpenSSL (`-lssl -lcrypto`) or use `cid-standalone.c` (no deps) |

## Quick Test

```bash
bash cid.sh test
python3 cid.py test
go run cid.go test
# Rust: cargo new cid-test && cp cid.rs src/main.rs && cargo run -- test
gcc -o cid cid.c -lssl -lcrypto && ./cid test
```

All should print `PASS` for every test case.
