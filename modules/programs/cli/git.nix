{ config, lib, ... }:
{
  programs = lib.mkIf config.programs.git.enable {
    delta = {
      enable = true;
      enableGitIntegration = true;
    };
    git.settings = {
      init.defaultBranch = "main";
    };
    gh.enable = true;
  };
}
