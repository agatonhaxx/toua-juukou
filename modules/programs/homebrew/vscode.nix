{ config, lib, ... }:
{
  config = lib.mkIf config.toua.programs.vscode.enable {
    homebrew.casks = [ "visual-studio-code" ];

    environment.customIcons = {
      enable = true;
      icons = [
        {
          path = "/Applications/Visual Studio Code.app";
          icon = ./icons/vscode.icns;
        }
      ];
    };
  };
}
