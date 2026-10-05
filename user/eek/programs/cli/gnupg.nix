{
  config,
  lib,
  ...
}:
{
  programs.gpg = lib.mkIf config.programs.gpg.enable {
    homedir = "${config.xdg.dataHome}/gnupg";
  };
}
