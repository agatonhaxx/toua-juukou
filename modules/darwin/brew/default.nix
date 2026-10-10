{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) importDir mkEnabledPackages;

  cfg = config.toua.homebrew;
  programs = config.toua.programs;
in
{
  # One module per program contributing a cask, tap or icon; they set Homebrew
  # and login-item options that only nix-darwin has. `importDir` skips this
  # file, so they are imported here.
  imports = importDir { dir = ./.; };

  # A machine installation cannot be toggled from Home Manager, so the host's
  # selection is mapped to package names here.
  homebrew.casks = mkEnabledPackages programs {
    bitwarden = "bitwarden";
    chromium = "google-chrome";
    discord = "discord";
    sf-symbols = "sf-symbols";
  };

  homebrew.brews = mkEnabledPackages programs {
    coreutils = "coreutils";
  };

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
