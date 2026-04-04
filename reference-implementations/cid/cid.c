/*
 * koad.generate.handle + koad.generate.cid — C reference implementation
 * Spec: VESTA-SPEC-027 (CID Privacy Primitive)
 *
 * Compile: gcc -o cid cid.c -lssl -lcrypto    (OpenSSL)
 *          gcc -o cid cid.c -lmbedcrypto       (mbedTLS alternative)
 *
 * Run:  ./cid test
 *       ./cid handle "https://github.com/koad"
 *       ./cid cid "httpsgithubcomkoad"
 *
 * Test vectors:
 *   handle("https://github.com/koad")  → "httpsgithubcomkoad"
 *   cid("httpsgithubcomkoad")          → "GdYZWjcjY6Y2XonnM"
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <openssl/sha.h>

#define CHARSET     "23456789ABCDEFGHJKLMNPQRSTWXYZabcdefghijkmnopqrstuvwxyz"
#define CHARSET_LEN 55
#define CID_LEN     17

/*
 * koad_handle: normalize str into out.
 * out must be at least strlen(str)+1 bytes.
 * Returns pointer to out.
 */
char *koad_handle(const char *str, char *out) {
    size_t j = 0;
    for (size_t i = 0; str[i]; i++) {
        unsigned char c = (unsigned char)str[i];
        if (isalnum(c)) {
            out[j++] = (char)tolower(c);
        }
    }
    out[j] = '\0';
    return out;
}

/*
 * koad_cid: compute 17-char CID from str.
 * out must be at least CID_LEN+1 bytes.
 * Returns pointer to out.
 */
char *koad_cid(const char *str, char *out) {
    char handle[4096];
    unsigned char digest[SHA256_DIGEST_LENGTH];

    koad_handle(str, handle);
    SHA256((const unsigned char *)handle, strlen(handle), digest);

    for (int i = 0; i < CID_LEN; i++) {
        out[i] = CHARSET[digest[i] % CHARSET_LEN];
    }
    out[CID_LEN] = '\0';
    return out;
}

int main(int argc, char *argv[]) {
    if (argc < 2 || strcmp(argv[1], "test") == 0) {
        typedef struct { const char *fn; const char *input; const char *want; } tc;
        tc cases[] = {
            {"handle", "https://github.com/koad", "httpsgithubcomkoad"},
            {"cid",    "httpsgithubcomkoad",        "GdYZWjcjY6Y2XonnM"},
            {"cid",    "koad",                       "TysPFWq8Nr5LZQQnM"},
        };

        puts("=== Test Vectors ===");
        for (int i = 0; i < 3; i++) {
            char result[256];
            if (strcmp(cases[i].fn, "handle") == 0)
                koad_handle(cases[i].input, result);
            else
                koad_cid(cases[i].input, result);

            int pass = strcmp(result, cases[i].want) == 0;
            printf("%s %s(\"%s\") = \"%s\"",
                   pass ? "PASS" : "FAIL",
                   cases[i].fn, cases[i].input, result);
            if (!pass) printf("  (want \"%s\")", cases[i].want);
            putchar('\n');
        }
        return 0;
    }

    if (argc < 3) {
        fprintf(stderr, "Usage: %s handle|cid|test <string>\n", argv[0]);
        return 1;
    }

    char out[256];
    if (strcmp(argv[1], "handle") == 0) {
        printf("%s\n", koad_handle(argv[2], out));
    } else if (strcmp(argv[1], "cid") == 0) {
        printf("%s\n", koad_cid(argv[2], out));
    } else {
        fprintf(stderr, "Usage: %s handle|cid|test <string>\n", argv[0]);
        return 1;
    }
    return 0;
}
