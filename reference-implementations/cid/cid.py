"""
koad.generate.handle + koad.generate.cid — Python reference implementation
Spec: VESTA-SPEC-027 (CID Privacy Primitive)

Requires: Python 3.6+ (hashlib is stdlib)

Test vectors:
    handle("https://github.com/koad")  → "httpsgithubcomkoad"
    cid("httpsgithubcomkoad")          → "GdYZWjcjY6Y2XonnM"
"""

import hashlib
import re

CHARSET = "23456789ABCDEFGHJKLMNPQRSTWXYZabcdefghijkmnopqrstuvwxyz"
CHARSET_LEN = 55
CID_LEN = 17


def handle(s: str) -> str:
    """Normalize: lowercase, strip non-alphanumeric characters."""
    return re.sub(r"[^a-z0-9]", "", s.lower())


def cid(s: str) -> str:
    """Compute a 17-character opaque CID from any string input."""
    h = handle(s)
    digest = hashlib.sha256(h.encode("utf-8")).digest()
    return "".join(CHARSET[digest[i] % CHARSET_LEN] for i in range(CID_LEN))


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2 or sys.argv[1] == "test":
        print("=== Test Vectors ===")
        cases = [
            ("handle", "https://github.com/koad", "httpsgithubcomkoad"),
            ("cid",    "httpsgithubcomkoad",        "GdYZWjcjY6Y2XonnM"),
            ("cid",    "koad",                       "TysPFWq8Nr5LZQQnM"),
        ]
        for fn, inp, expected in cases:
            result = handle(inp) if fn == "handle" else cid(inp)
            status = "PASS" if result == expected else "FAIL"
            print(f"{status} {fn}({inp!r}) = {result!r}" +
                  (f"  (want {expected!r})" if result != expected else ""))
    elif sys.argv[1] == "handle":
        print(handle(sys.argv[2]))
    elif sys.argv[1] == "cid":
        print(cid(sys.argv[2]))
    else:
        print(f"Usage: {sys.argv[0]} handle|cid|test <string>", file=sys.stderr)
        sys.exit(1)
