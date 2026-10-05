{ osConfig, pkgs, ... }:
{
  assertions = [
    {
      assertion = pkgs.stdenv.hostPlatform.isDarwin || !osConfig.toua.programs.kiwidesk.enable;
      message = "toua.programs.kiwidesk.enable is only supported on Darwin";
    }
  ];

}
