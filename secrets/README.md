# Secrets

Encrypted with [sops](https://github.com/getsops/sops), decrypted on hosts by
[sops-nix](https://github.com/Mic92/sops-nix). Layout and rules mirror the
dotfiles repo.

Neither `sops` nor `ssh-to-age` is installed on the hosts; run them out of
nixpkgs:

```sh
nix shell nixpkgs#sops nixpkgs#ssh-to-age
```

## Layout

- `eek.yaml` — your own secrets (the user password hash, personal API keys)
- `services/<name>.yaml` — per-service secrets

Both are encrypted to your age key plus every host's age key; see
`../.sops.yaml` for the creation rules.

## Editing

```sh
sops secrets/eek.yaml          # edit in $EDITOR
sops secrets/services/foo.yaml
```

`sops` discovers `../.sops.yaml` automatically when run from the repo root.

## Rotating

Re-encrypt a file with a fresh data key:

```sh
sops rotate -i secrets/eek.yaml
```

All of them at once:

```sh
find secrets/ -name '*.yaml' | xargs -I {} sops rotate -i {}
```

## Adding a new host

The host's age identity is derived from its SSH host ed25519 key, so that key
has to exist before the host can be added as a recipient. Hosts with
`services.openssh.enable = true` already have one. For hosts without it — WSL,
or anything where you don't want an sshd running — set:

```nix
services.openssh.generateHostKeys = true;
```

That generates `/etc/ssh/ssh_host_ed25519_key` without starting the daemon.
Generation happens in `sshd-keygen.service`, a systemd unit pulled in by
`multi-user.target`, so it only runs once activation has succeeded — a rebuild
that fails activation leaves no key behind. Get the key in place before the
host consumes any `sops.secrets`; see the bootstrap note below if you are
already past that point.

Then, on the host, print its `age1…` recipient:

```sh
nix shell nixpkgs#ssh-to-age -c ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
```

Read the public half only — never the private key.

Add the recipient as an anchor in `../.sops.yaml`, list the anchor in **both**
key groups (`secrets/eek.yaml` and `secrets/services/`), then push the change
into every existing secret so the new host can read them:

```sh
find secrets/ -name '*.yaml' | xargs -I {} sops updatekeys -y {}
```

No key provisioning on the host is needed — `modules/shared/secrets.nix` points
sops-nix at the SSH host key directly, so the host derives its age identity from
the key it already has.

### Bootstrapping a host that has no key yet

`sops updatekeys` has to decrypt each file before it can re-encrypt it, so it
needs a key that is already a recipient. A brand new host is not one yet, which
makes the order above circular. Break it by giving the host its SSH key first,
while it still has no `sops.secrets` of its own:

1. On the new host, add `services.openssh.generateHostKeys = true;` and
   rebuild. With no `sops.secrets` declared yet, activation succeeds,
   `sshd-keygen.service` runs, and `/etc/ssh/ssh_host_ed25519_key` appears.
2. Run `ssh-to-age` as above and add the recipient to `../.sops.yaml`.
3. Run `sops updatekeys` from a machine you already have a key for.
4. Now add the host's `sops.secrets` and rebuild. It succeeds this time.

If the host is already consuming secrets, so that step 1 cannot complete,
generate the key by hand instead — nothing has to succeed first, which is what
breaks the cycle:

```sh
sudo ssh-keygen -t ed25519 -N '' -f /etc/ssh/ssh_host_ed25519_key
```

Then carry on from step 2. `sshd-keygen.service` skips keys that already exist,
so the two routes are interchangeable.

## Changing who can decrypt

After editing the recipients in `../.sops.yaml`, push the change into the
encrypted files:

```sh
sops updatekeys secrets/eek.yaml
```

Without `-y` sops asks for confirmation per file, which is what you want when
the change removes a recipient.

## Consuming in a module

Helpers live in `modules/shared/lib.nix`. `mkSecret` resolves the file path for
you; any other argument is passed through to the secret definition.

```nix
{
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../lib.nix { inherit lib self; }) mkSecret;
  cfg = config.toua.services.foo;
in
{
  config = lib.mkIf cfg.enable {
    sops.secrets.foo-env = mkSecret {
      file = "foo";
      key = "env";
      owner = config.toua.primaryUser;
      mode = "0400";
    };

    systemd.services.foo.serviceConfig.EnvironmentFile =
      config.sops.secrets.foo-env.path;
  };
}
```

`dir` defaults to `services`; pass `dir = ""` for a file at the top level of
`secrets/`:

```nix
sops.secrets.user-password = mkSecret {
  file = "eek";
  dir = "";
  key = "password";
};
```

For services that also want the standard `toua.services.<name> = { enable, host,
port, domain }` options, `mkServiceOption` from the same file builds them:

```nix
{
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../lib.nix { inherit lib self; }) mkSecret mkServiceOption;
  cfg = config.toua.services.foo;
in
{
  options.toua.services.foo = mkServiceOption "foo" {
    port = 8080;
    domain = "foo.example.com";
  };

  config = lib.mkIf cfg.enable {
    # …
  };
}
```
