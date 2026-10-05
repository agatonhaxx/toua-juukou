{
  lib,
  pkgs,
  osConfig,
  ...
}:
{
  config = lib.mkIf osConfig.toua.fonts.enable {
    home.packages = with pkgs; [
      # keep-sorted start
      departure-mono
      nerd-fonts._0xproto
      nerd-fonts.commit-mono
      nerd-fonts.lilex
      # keep-sorted end
    ];
  };
}
