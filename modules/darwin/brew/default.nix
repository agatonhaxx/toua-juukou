{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) importDir;

  cfg = config.toua.homebrew;
in
{
  # What macOS installs through Homebrew: the installation itself below, and one
  # module per program that contributes a cask, a tap or an icon. They live here
  # rather than under modules/programs because they set Homebrew and login-item
  # options that only nix-darwin has.
  imports = importDir { dir = ./.; };

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
