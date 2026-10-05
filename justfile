flake := env("FLAKE", justfile_directory())
local-host := if os() == "macos" { "mac" } else { `hostname -s` }

[private]
default:
    @just --list --unsorted

# Rebuilds

[group("rebuild")]
[private]
[no-exit-message]
rebuild host goal *args:
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ "$(uname -s)" == "Darwin" ]]; then
      if [[ "{{ host }}" != "mac" ]]; then
        echo "Darwin can only rebuild the mac output locally; use 'just deploy' for a remote NixOS host." >&2
        exit 2
      fi
      sudo darwin-rebuild "{{ goal }}" --flake "{{ flake }}#{{ host }}" {{ args }}
    else
      sudo nixos-rebuild "{{ goal }}" --flake "{{ flake }}#{{ host }}" {{ args }}
    fi

# Build a host without activating it.
[group("rebuild")]
[no-exit-message]
build host=local-host *args: (rebuild host "build" args)

# Build a host and explain how its system differs from the one now running.
[group("rebuild")]
[no-exit-message]
diff host=local-host *args:
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ "{{ host }}" == "mac" ]]; then
      attr=darwinConfigurations
    else
      attr=nixosConfigurations
    fi

    # Building also instantiates the derivation, which is what nix-diff reads.
    out=$(nix build --no-link --print-out-paths \
      "{{ flake }}#${attr}.{{ host }}.config.system.build.toplevel" {{ args }})

    current=/run/current-system
    old_drv=$(nix-store --query --deriver "$current" 2>/dev/null || true)
    if [[ -z "$old_drv" ]]; then
      # The running system's derivation is gone (garbage collected), so fall
      # back to the closure-level comparison, which needs no derivation.
      echo "No derivation left for $current; comparing closures instead." >&2
      exec nix store diff-closures "$current" "$out"
    fi

    exec nix-diff "$old_drv" "$(nix-store --query --deriver "$out")"

# Activate a host configuration locally.
[group("rebuild")]
[no-exit-message]
switch host=local-host *args: (rebuild host "switch" args)

# Activate a NixOS configuration until the next reboot.
[group("rebuild")]
[linux]
[no-exit-message]
test host=local-host *args: (rebuild host "test" args)

# Set the next NixOS boot generation without switching now.
[group("rebuild")]
[linux]
[no-exit-message]
boot host=local-host *args: (rebuild host "boot" args)

# Switch a NixOS host over SSH, for example: just deploy wall-e root@wall-e.huxe.eu
[group("rebuild")]
[no-exit-message]
deploy host target *args:
    #!/usr/bin/env bash
    set -euo pipefail

    if command -v nixos-rebuild >/dev/null 2>&1; then
      rebuild=(nixos-rebuild)
    else
      # nixos-rebuild is not installed by nix-darwin, so run the ng frontend
      # from nixpkgs when deploying a NixOS machine from the Mac.
      rebuild=(nix run nixpkgs#nixos-rebuild-ng --)
    fi

    "${rebuild[@]}" switch \
      --flake "{{ flake }}#{{ host }}" \
      --build-host "{{ target }}" \
      --target-host "{{ target }}" {{ args }}

# Provision wall-e from scratch. This applies disko and wipes its target disk.
[group("rebuild")]
[confirm("Provision wall-e and wipe the target disk?")]
[no-exit-message]
provision-wall-e target *args:
    nixos-anywhere --flake "{{ flake }}#wall-e" --target-host "{{ target }}" {{ args }}

# Development

# Format the repository with its flake formatter.
[group("dev")]
fmt:
    nix fmt

# Run all flake checks.
[group("dev")]
[no-exit-message]
check *args:
    nix flake check --option allow-import-from-derivation false {{ args }}

# List the registered NixOS and Darwin host outputs.
[group("dev")]
hosts:
    #!/usr/bin/env bash
    set -euo pipefail
    nix eval --json "{{ flake }}#nixosConfigurations" --apply builtins.attrNames 2>/dev/null || printf '[]\n'
    nix eval --json "{{ flake }}#darwinConfigurations" --apply builtins.attrNames 2>/dev/null || printf '[]\n'

# Update all inputs, or only the named inputs: just update nixpkgs home-manager
[group("dev")]
[no-exit-message]
update *inputs:
    nix flake update {{ inputs }} --flake "{{ flake }}"

# Open a REPL for one host's evaluated configuration.
[group("dev")]
repl host=local-host:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{ host }}" == "mac" ]]; then
      exec nix repl "{{ flake }}#darwinConfigurations.{{ host }}"
    fi
    exec nix repl "{{ flake }}#nixosConfigurations.{{ host }}"

# Secrets

# Edit a SOPS file, for example: just secret secrets/services/vaultwarden.yaml
[group("secrets")]
secret path:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ path }}" in
      secrets/*) ;;
      *) echo "secret path must be below secrets/" >&2; exit 2 ;;
    esac
    if command -v sops >/dev/null 2>&1; then
      exec sops "{{ path }}"
    fi
    exec nix shell nixpkgs#sops -c sops "{{ path }}"

# Print the age recipient derived from an SSH public key.
[group("secrets")]
age-recipient public-key="/etc/ssh/ssh_host_ed25519_key.pub":
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v ssh-to-age >/dev/null 2>&1; then
      exec ssh-to-age < "{{ public-key }}"
    fi
    exec nix shell nixpkgs#ssh-to-age -c sh -c 'ssh-to-age < "$1"' _ "{{ public-key }}"

# Add the recipients in .sops.yaml to every existing encrypted file.
# Run this using an identity that can already decrypt the files.
[group("secrets")]
[no-exit-message]
secrets-update:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v sops >/dev/null 2>&1; then
      sops=(sops)
    else
      sops=(nix shell nixpkgs#sops -c sops)
    fi
    while IFS= read -r -d '' path; do
      "${sops[@]}" updatekeys -y "$path"
    done < <(find secrets -type f -name '*.yaml' -print0)

# Rotate every secret's data-encryption key without changing its recipients.
[group("secrets")]
[no-exit-message]
secrets-rotate:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v sops >/dev/null 2>&1; then
      sops=(sops)
    else
      sops=(nix shell nixpkgs#sops -c sops)
    fi
    while IFS= read -r -d '' path; do
      "${sops[@]}" rotate -i "$path"
    done < <(find secrets -type f -name '*.yaml' -print0)

# Store maintenance

alias fix := repair

# Verify the Nix store.
[group("store")]
[no-exit-message]
verify *args:
    nix-store --verify {{ args }}

# Verify and repair damaged Nix store paths.
[group("store")]
[no-exit-message]
repair: (verify "--check-contents --repair")

# Delete generations older than seven days, then optimise the store.
[group("store")]
[confirm("Delete Nix generations older than seven days?")]
[no-exit-message]
clean:
    nix-collect-garbage --delete-older-than 7d
    nix store optimise
