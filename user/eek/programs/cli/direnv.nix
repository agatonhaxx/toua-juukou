{ config, lib, ... }:
{
  programs.direnv = lib.mkIf config.programs.direnv.enable {
    nix-direnv.enable = true;

    config = {
      whitelist.prefix = [ "~/dev/projects" ];
    };
  };
}
