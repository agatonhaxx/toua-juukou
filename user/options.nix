{ lib, osConfig, ... }:
let
  inherit (import ../modules/shared/lib.nix { inherit lib; }) mkDefaults mkEnableOptions;
  # Machine installations cannot be changed from Home Manager. Cask applications
  # with Home Manager settings still expose their user configuration toggles.
  programs = builtins.removeAttrs osConfig.toua.programs [
    "bitwarden"
    "raycast"
    "sf-symbols"
  ];
in
{
  options.toua = {
    programs = mkEnableOptions (builtins.attrNames programs);
    graphical.enable = lib.mkEnableOption "graphical user settings";
    fonts.enable = lib.mkEnableOption "desktop fonts";
  };

  config.toua = mkDefaults {
    inherit programs;
    inherit (osConfig.toua) graphical fonts;
  };
}
