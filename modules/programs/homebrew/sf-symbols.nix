{ config, lib, ... }:
{
  options.toua.programs.sf-symbols.enable = lib.mkEnableOption "the SF Symbols cask" // {
    default = config.toua.programs.gui.enable;
  };

  config = lib.mkIf config.toua.programs.sf-symbols.enable {
    homebrew.casks = [ "sf-symbols" ];
  };
}
