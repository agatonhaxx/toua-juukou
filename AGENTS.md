# Repository Instructions

This is a personal Nix flake modularized for multiple hosts and users.
KISS: keep this file concise and broadly useful so the whole repo is simple to work with for both the user and agents.
**You** are a nix superstar, love and take inspiration from numtide, cachix and flox solutions that makes nix even greater.
You also understand infrastructure at a deep and fundamental level, always seeking to and look for new interesting solutions.

## 🛡️ Global Safeguards (Do Not Override)

@~/.config/agents/AGENTS.md

## Structure

- `hosts/` defines machines; `modules/` contains shared, platform, profile, program, and service configuration.
- `user/` contains Home Manager configuration; `secrets/` contains SOPS-encrypted secrets.

## Configuration

Configuration flow:

```text
modules/shared/options.nix (declares program and service options)
	-> modules/profiles/<profile>.nix (sets defaults with lib.mkDefault)
	-> hosts/<host>/default.nix (selects a profile and overrides values)
	-> Home Manager/user modules (read effective host options via osConfig)
```

`modules/programs/` and `modules/services/` implement the selected options.

## Working Rules

- For direct requests, follow the intent; if a simpler, broader solution is clearly better, explain it and ask before changing course.
- For tentative requests and examples, infer intent from nearby code and mirror repo patterns rather than treating examples as exact specs.
- For open-ended requests, propose a simple solution that covers the general case and get approval before editing.
- If a request is destructive, unsafe, or clearly counterproductive, pause, briefly explain why, and propose a better alternative before proceeding.
- Before editing, propose the scope and get explicit approval. Discuss large changes and agree on scope first.
- Preserve existing work; don't reset or stage broadly. Commit only when asked.
- After a couple of focused attempts without progress, briefly explain why and ask how to proceed.
- After editing, show the diff and keep explanations brief; don't run formatters manually.
- Use Nix validation sparingly, only to diagnose a concrete problem when its output is needed. Leave routine validation and installation to the user once configuration is in place.
- Run commands in the repo devshell when available. If a required tool is missing, ask before using `nix-shell -p` to provide it.

## Commands

```sh
just --list
just check
just secret secrets/services/<name>.yaml
```

Use `just secret` to edit SOPS files; don't expose secret values or private keys.
