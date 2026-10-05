{ config, lib, ... }:
{
  options.toua.programs.bitwarden.enable = lib.mkEnableOption "the Bitwarden cask" // {
    default = config.toua.programs.gui.enable;
  };

  config = lib.mkIf config.toua.programs.bitwarden.enable {
    homebrew.casks = [ "bitwarden" ];
  };
}
