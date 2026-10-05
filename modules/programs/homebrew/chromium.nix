{ config, lib, ... }:
{
  homebrew.casks = lib.mkIf config.toua.programs.chromium.enable [ "ungoogled-chromium" ];
}
