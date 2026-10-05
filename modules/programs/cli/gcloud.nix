{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  home.packages = lib.mkIf osConfig.toua.programs.gcloud.enable [ pkgs.google-cloud-sdk ];
}
