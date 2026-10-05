{
  lib,
  config,
  ...
}:
{
  programs.zsh = lib.mkIf config.programs.zsh.enable {
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history.path = "${config.xdg.dataHome}/zsh/zsh_history";
    dotDir = "${config.xdg.configHome}/zsh";
  };
}
