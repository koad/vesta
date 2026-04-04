// koad.generate.handle + koad.generate.cid — Rust reference implementation
// Spec: VESTA-SPEC-027 (CID Privacy Primitive)
//
// Build:  cargo build --release  (or rustc cid.rs for standalone)
// Run:    ./cid test
//         ./cid handle "https://github.com/koad"
//         ./cid cid "httpsgithubcomkoad"
//
// Test vectors:
//   handle("https://github.com/koad")  → "httpsgithubcomkoad"
//   cid("httpsgithubcomkoad")          → "GdYZWjcjY6Y2XonnM"
//
// Dependencies (Cargo.toml):
//   [dependencies]
//   sha2 = "0.10"
//
// For standalone compilation (no cargo):
//   Add sha2 manually or use ring/openssl bindings.

use sha2::{Digest, Sha256};
use std::env;

const CHARSET: &[u8] = b"23456789ABCDEFGHJKLMNPQRSTWXYZabcdefghijkmnopqrstuvwxyz";
const CHARSET_LEN: usize = 55;
const CID_LEN: usize = 17;

/// Normalize: lowercase, strip non-alphanumeric characters.
fn handle(s: &str) -> String {
    s.to_lowercase()
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .collect()
}

/// Compute a 17-character opaque CID from any string input.
fn cid(s: &str) -> String {
    let h = handle(s);
    let digest = Sha256::digest(h.as_bytes());
    (0..CID_LEN)
        .map(|i| CHARSET[digest[i] as usize % CHARSET_LEN] as char)
        .collect()
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 || args[1] == "test" {
        println!("=== Test Vectors ===");
        let cases = vec![
            ("handle", "https://github.com/koad", "httpsgithubcomkoad"),
            ("cid",    "httpsgithubcomkoad",        "GdYZWjcjY6Y2XonnM"),
            ("cid",    "koad",                       "TysPFWq8Nr5LZQQnM"),
        ];
        for (fn_name, input, expected) in &cases {
            let got = if *fn_name == "handle" { handle(input) } else { cid(input) };
            let status = if got == *expected { "PASS" } else { "FAIL" };
            print!("{} {}({:?}) = {:?}", status, fn_name, input, got);
            if got != *expected {
                print!("  (want {:?})", expected);
            }
            println!();
        }
        return;
    }

    if args.len() < 3 {
        eprintln!("Usage: {} handle|cid|test <string>", args[0]);
        std::process::exit(1);
    }

    match args[1].as_str() {
        "handle" => println!("{}", handle(&args[2])),
        "cid"    => println!("{}", cid(&args[2])),
        _ => {
            eprintln!("Usage: {} handle|cid|test <string>", args[0]);
            std::process::exit(1);
        }
    }
}
