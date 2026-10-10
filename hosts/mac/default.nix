{
  config,
  lib,
  ...
}:
let
  groups = import ../../modules/groups.nix;
  inherit (import ../../modules/shared/lib.nix { inherit lib; }) mkDefaults;
  # The machine name and the work identity must never sit next to each other in
  # this public repository, so both live encrypted in `secrets/eek.yaml` and are
  # rendered at activation. The repository only holds the key names. sops-nix
  # only ever exposes a secret as a file on disk, which is what keeps the value
  # out of the Nix store.
  secretsFile = ../../secrets/eek.yaml;
in
{
  imports = [
    ../../user
  ];

  # macOS's `path_helper` rewrites $PATH at every login and puts Apple's
  # binaries ahead of the Nix ones. `user/shells/fish.nix` re-prepends the Nix
  # directories in `loginShellInit` to undo that — the block it does it in is
  # generic, because fish never reads /etc/profile and so needs the same
  # prepend for a working PATH on NixOS. The macOS reason is written down here,
  # on the host it applies to.
  # https://github.com/LnL7/nix-darwin/issues/122

  toua = lib.mkMerge [
    (mkDefaults groups.agents)
    (mkDefaults groups.dev)
    (mkDefaults groups.k8s)
    {
      primaryUser = "Glenn.Dahl";
      profiles.mac.enable = true;

      programs = {
        # keep-sorted start
        kiwidesk.enable = true;
        qbittorrent.enable = false;
        # keep-sorted end
      };
    }
  ];

  users = {
    users."Glenn.Dahl".uid = 502;
    knownUsers = [ "Glenn.Dahl" ];
  };

  # nix-darwin writes the hostname itself whenever these are set, and easy-hosts
  # would otherwise default `hostName` to the flake host name `mac`. Both are
  # suppressed: the activation script below is the only writer and takes the
  # name from a secret.
  networking = {
    computerName = null;
    hostName = null;
    localHostName = null;
  };

  sops = {
    secrets = {
      mac-hostname = {
        sopsFile = secretsFile;
        # sops-nix addresses nested YAML with `/`; a dot would be looked up as
        # one literal key called `work.hostname`.
        key = "work/hostname";
      };
    };
  };

  # `mkOrder 1600` sorts this after sops-nix's own contribution to the same
  # option (it uses `mkAfter`, priority 1500), so the secret is on disk by the
  # time this runs. Without the ordering the name would only appear from the
  # second activation onwards.
  system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
    hostname_file=${lib.escapeShellArg config.sops.secrets.mac-hostname.path}
    if [ -r "$hostname_file" ]; then
      hostname="$(cat "$hostname_file")"
      /usr/sbin/scutil --set ComputerName "$hostname"
      /usr/sbin/scutil --set HostName "$hostname"
      /usr/sbin/scutil --set LocalHostName "$hostname"
    fi
  '';

  security.pam.services.sudo_local.touchIdAuth = true;
}
