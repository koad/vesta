// koad.generate.handle + koad.generate.cid — Go reference implementation
// Spec: VESTA-SPEC-027 (CID Privacy Primitive)
//
// go run cid.go test
// go run cid.go handle "https://github.com/koad"
// go run cid.go cid "httpsgithubcomkoad"
//
// Test vectors:
//   handle("https://github.com/koad")  → "httpsgithubcomkoad"
//   cid("httpsgithubcomkoad")          → "GdYZWjcjY6Y2XonnM"

package main

import (
	"crypto/sha256"
	"fmt"
	"os"
	"strings"
	"unicode"
)

const (
	charset    = "23456789ABCDEFGHJKLMNPQRSTWXYZabcdefghijkmnopqrstuvwxyz"
	charsetLen = 55
	cidLen     = 17
)

// Handle normalizes a string: lowercase, strip non-alphanumeric characters.
func Handle(s string) string {
	s = strings.ToLower(s)
	var b strings.Builder
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// CID computes a 17-character opaque identifier from any string input.
func CID(s string) string {
	h := Handle(s)
	digest := sha256.Sum256([]byte(h))
	result := make([]byte, cidLen)
	for i := 0; i < cidLen; i++ {
		result[i] = charset[int(digest[i])%charsetLen]
	}
	return string(result)
}

func main() {
	if len(os.Args) < 2 || os.Args[1] == "test" {
		fmt.Println("=== Test Vectors ===")
		type tc struct{ fn, input, want string }
		cases := []tc{
			{"handle", "https://github.com/koad", "httpsgithubcomkoad"},
			{"cid", "httpsgithubcomkoad", "GdYZWjcjY6Y2XonnM"},
			{"cid", "koad", "TysPFWq8Nr5LZQQnM"},
		}
		for _, c := range cases {
			var got string
			if c.fn == "handle" {
				got = Handle(c.input)
			} else {
				got = CID(c.input)
			}
			status := "PASS"
			if got != c.want {
				status = "FAIL"
			}
			fmt.Printf("%s %s(%q) = %q", status, c.fn, c.input, got)
			if got != c.want {
				fmt.Printf("  (want %q)", c.want)
			}
			fmt.Println()
		}
		return
	}

	if len(os.Args) < 3 {
		fmt.Fprintf(os.Stderr, "Usage: %s handle|cid|test <string>\n", os.Args[0])
		os.Exit(1)
	}

	switch os.Args[1] {
	case "handle":
		fmt.Println(Handle(os.Args[2]))
	case "cid":
		fmt.Println(CID(os.Args[2]))
	default:
		fmt.Fprintf(os.Stderr, "Usage: %s handle|cid|test <string>\n", os.Args[0])
		os.Exit(1)
	}
}
