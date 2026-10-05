{
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  programs.vscode = {
    enable = lib.mkDefault osConfig.toua.programs.vscode.enable;
    package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin null;
  };
}
