{ config, lib, ... }:
let
  groups = import ../../modules/groups.nix;
  inherit (import ../../modules/shared/lib.nix { inherit lib; }) mkDefaults;
in
{
  imports = [ ../../user ];

  # WSL keeps the shared terminal setup and the tailnet, and nothing graphical.
  toua = lib.mkMerge [
    (mkDefaults groups.cli)
    (mkDefaults groups.network)
    #TODO add copy paste to wsl from windows
  ];

  programs.nix-ld.enable = true;

  # sops-nix derives this host's age identity from its SSH host ed25519 key, and
  # WSL runs no sshd, so the key has to be generated without a daemon.
  services.openssh.generateHostKeys = true;

  wsl = {
    enable = true;
    defaultUser = config.toua.primaryUser;
    startMenuLaunchers = true;

    wslConf.network.hostname = "ponkotsu";
  };
}
