{ config, lib, ... }:
{
  homebrew.brews = lib.mkIf config.toua.programs.coreutils.enable [ "coreutils" ];
}
