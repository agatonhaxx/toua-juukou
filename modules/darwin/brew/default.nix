{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.toua.homebrew;
in
{
  imports = [
    ../../programs/homebrew
    ./environment.nix
  ];

  config = lib.mkIf cfg.enable {
    # nix-homebrew owns the installation; nix-darwin's Homebrew module owns
    # the declarative taps, formulae, and casks supplied by the host.
    nix-homebrew = {
      enable = true;
      enableRosetta = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 true;
      user = config.toua.primaryUser;
      autoMigrate = true;
    };

    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = true;
        cleanup = "uninstall";
        upgrade = true;
        # TODO: Temporary fix for https://github.com/nix-darwin/nix-darwin/issues/1787.
        extraFlags = [ "--force-cleanup" ];
      };
    };
  };
}
