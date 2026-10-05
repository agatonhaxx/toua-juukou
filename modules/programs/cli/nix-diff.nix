{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  home.packages = lib.mkIf osConfig.toua.programs.nix-diff.enable [ pkgs.nix-diff ];
}
