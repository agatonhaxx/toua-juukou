{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  home.packages = lib.mkIf osConfig.toua.programs.helm.enable [ pkgs.kubernetes-helm ];
}
