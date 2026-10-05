{ config, lib, ... }:
{
  programs.fd = lib.mkIf config.programs.fd.enable {
    hidden = true;
    ignores = [
      ".Trash"
      ".git"
      "**/node_modules"
      "**/target"
    ];
    extraOptions = [ "--no-ignore-vcs" ];
  };
}
