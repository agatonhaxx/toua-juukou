function mkpasswd2 --description 'Ask for a password twice, then print its SHA-512 crypt hash'
    # The newlines tidy up after `-s`, which suppresses the echo of the user's
    # own Enter. They go to stderr so that stdout carries the hash and nothing
    # else.
    read -l -s -P 'Password: ' p1
    echo >&2
    read -l -s -P 'Retype password: ' p2
    echo >&2

    if test "$p1" != "$p2"
        echo 'mkpasswd2: passwords do not match' >&2
        return 1
    end

    # `mkpasswd -s` reads one line and hashes it without the line terminator, so
    # the newline `printf` adds does not end up inside the password.
    if command -q mkpasswd
        printf '%s\n' "$p1" | mkpasswd -m sha-512 -s
    else
        printf '%s\n' "$p1" | nix run nixpkgs#mkpasswd -- -m sha-512 -s
    end
end
