{ config, ... }:
{
  imports = [ ../../user ];

  toua = {
    profiles.wsl.enable = true;
    primaryUser = "eek";
    users.eek.homeModule = ../../user/eek;
    #TODO add copy paste to wsl from windows
  };

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
