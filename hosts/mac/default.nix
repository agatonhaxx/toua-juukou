{
  config,
  lib,
  ...
}:
let
  groups = import ../../modules/groups.nix;
  inherit (import ../../modules/shared/lib.nix { inherit lib; }) mkDefaults;
  # The machine name and the work identity are encrypted in `secrets/eek.yaml` —
  # this repo is public — and sops-nix renders them as files, never into the store.
  secretsFile = ../../secrets/eek.yaml;
in
{
  imports = [
    ../../user
  ];

  # macOS's `path_helper` puts Apple's binaries ahead of the Nix ones at every
  # login, so `user/shells/fish.nix` re-prepends them (nix-darwin#122).

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

  # Suppressed because the activation script below is the only writer: nix-darwin
  # writes the hostname itself, and easy-hosts would default it to the flake name.
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

  # `mkOrder 1600` lands this after sops-nix's own `mkAfter` (1500), so the secret
  # is on disk; without it the name only appears from the second activation on.
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
