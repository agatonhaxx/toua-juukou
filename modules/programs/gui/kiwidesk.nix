{ config, pkgs, ... }:
{
  assertions = [
    {
      assertion = pkgs.stdenv.hostPlatform.isDarwin || !config.toua.programs.kiwidesk.enable;
      message = "toua.programs.kiwidesk.enable is only supported on Darwin";
    }
  ];

}
