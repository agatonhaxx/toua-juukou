{
  lib,
  config,
  ...
}:
{
  programs.bash = lib.mkIf config.programs.bash.enable {
    historyFile = "${config.xdg.dataHome}/bash/bash_history";
  };
}
