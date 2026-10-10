{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  inherit (import ./lib.nix { inherit lib; }) mkEnableOptions;
  groups = import ../groups.nix;
  # Cask-only options are declared in modules/darwin/options.nix.
  programNames = lib.unique (
    lib.concatMap (name: builtins.attrNames (groups.${name}.programs or { })) (
      builtins.attrNames (builtins.removeAttrs groups [ "mac" ])
    )
  );
in
{
  options.toua = {
    primaryUser = mkOption {
      type = types.str;
      default = "eek";
      description = "Primary user for machine integrations.";
    };

    users = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkEnableOption "Manage this user";
            homeModule = mkOption {
              type = types.path;
              # The repo's user tree. A second user needs its own, named on the
              # host.
              default = ../../user/eek;
              description = "Home Manager module for this user.";
            };
          };
        }
      );
      default = { };
      description = "Users managed by this host, keyed by username.";
    };

    timeZone = mkOption {
      type = types.str;
      default = "Europe/Stockholm";
      description = "System time zone, applied on every platform.";
    };

    programs = mkEnableOptions (
      programNames
      ++ [
        "kiwidesk"
        "niri"
      ]
    );
    graphical.enable = mkEnableOption "graphical user settings";
    fonts.enable = mkEnableOption "desktop fonts";
  };
}
