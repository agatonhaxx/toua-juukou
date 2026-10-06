{
  lib,
  config,
  pkgs,
  ...
}:
{
  programs.vscode = {
    enable = lib.mkDefault config.toua.programs.vscode.enable;
    package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin null;
  };
}
