#!/usr/bin/env bash
# koad.generate.handle + koad.generate.cid — Bash reference implementation
# Spec: VESTA-SPEC-027 (CID Privacy Primitive)
#
# Requires: coreutils (tr), openssl or sha256sum
#
# Test vectors:
#   handle "https://github.com/koad"  → httpsgithubcomkoad
#   cid    "httpsgithubcomkoad"        → GdYZWjcjY6Y2XonnM

readonly CHARSET="23456789ABCDEFGHJKLMNPQRSTWXYZabcdefghijkmnopqrstuvwxyz"
readonly CHARSET_LEN=55
readonly CID_LEN=17

koad_handle() {
    # Lowercase, strip non-alphanumeric
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

koad_cid() {
    local input="$1"
    local h
    h="$(koad_handle "$input")"

    # SHA256 as raw bytes (hex), then take first CID_LEN bytes
    local hexdigest
    if command -v sha256sum >/dev/null 2>&1; then
        hexdigest="$(printf '%s' "$h" | sha256sum | awk '{print $1}')"
    else
        hexdigest="$(printf '%s' "$h" | openssl dgst -sha256 | awk '{print $2}')"
    fi

    local cid=""
    for ((i = 0; i < CID_LEN; i++)); do
        # Extract byte i from hex digest (2 hex chars per byte)
        local byte_hex="${hexdigest:$((i * 2)):2}"
        local byte_val=$((16#$byte_hex))
        local idx=$((byte_val % CHARSET_LEN))
        cid+="${CHARSET:$idx:1}"
    done

    printf '%s' "$cid"
}

# CLI usage: cid.sh handle <string> | cid.sh cid <string>
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        handle) koad_handle "$2"; echo ;;
        cid)    koad_cid "$2"; echo ;;
        test)
            echo "=== Test Vectors ==="
            result_handle="$(koad_handle 'https://github.com/koad')"
            result_cid="$(koad_cid 'httpsgithubcomkoad')"
            [[ "$result_handle" == "httpsgithubcomkoad" ]] \
                && echo "PASS handle: $result_handle" \
                || echo "FAIL handle: got $result_handle, want httpsgithubcomkoad"
            [[ "$result_cid" == "GdYZWjcjY6Y2XonnM" ]] \
                && echo "PASS cid:    $result_cid" \
                || echo "FAIL cid:    got $result_cid, want GdYZWjcjY6Y2XonnM"
            ;;
        *) echo "Usage: $0 handle|cid|test <string>" >&2; exit 1 ;;
    esac
fi
