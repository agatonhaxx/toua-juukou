{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  home.packages = lib.mkIf osConfig.toua.programs.yubikey-manager.enable [ pkgs.yubikey-manager ];
}
