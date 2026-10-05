{ config, lib, ... }:
{
  # Home Manager installs WezTerm; this module adds its macOS login item.
  environment.loginItems = lib.mkIf config.toua.programs.wezterm.enable {
    enable = true;
    items = [ "/Applications/WezTerm.app" ];
  };
}
