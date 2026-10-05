{ config, lib, ... }:
{
  programs.zoxide = lib.mkIf config.programs.zoxide.enable {
    enableFishIntegration = true;
  };
}
