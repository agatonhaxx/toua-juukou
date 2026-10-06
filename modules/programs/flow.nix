{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = lib.mkIf config.toua.programs.flow.enable [ pkgs.flow ];
}
