{
  config,
  lib,
  ...
}:
let
  inherit (import ./lib.nix { inherit lib; }) importDir;
in
{
  # `lib.nix` holds helpers rather than a module, so it is skipped.
  imports = [
    ../programs/flow.nix
  ]
  ++ importDir {
    dir = ./.;
    exclude = [ "lib.nix" ];
  };

  programs.fish.enable = true;
  programs.fish.useBabelfish = true;

  # Both NixOS and nix-darwin declare this option, so it can be set from the
  # shared module rather than repeated per platform.
  time.timeZone = config.toua.timeZone;
}
