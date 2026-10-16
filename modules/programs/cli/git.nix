{ config, lib, ... }:
{
  programs.delta = lib.mkIf config.programs.git.enable {
    enable = true;
    enableGitIntegration = true;
  };
}
