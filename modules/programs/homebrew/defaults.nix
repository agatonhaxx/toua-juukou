{ config, lib, ... }:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkEnabledPackages;
  cfg = config.toua.programs;
in
{
  homebrew.casks = mkEnabledPackages cfg {
    bitwarden = "bitwarden";
    chromium = "google-chrome";
    sf-symbols = "sf-symbols";
  };
  homebrew.brews = mkEnabledPackages cfg {
    coreutils = "coreutils";
  };
}
