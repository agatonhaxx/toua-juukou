{
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  assertions = [
    {
      assertion = pkgs.stdenv.hostPlatform.isLinux || !osConfig.toua.programs.niri.enable;
      message = "toua.programs.niri.enable is only supported on Linux";
    }
  ];

  wayland.windowManager.niri.enable = lib.mkDefault (
    pkgs.stdenv.hostPlatform.isLinux && osConfig.toua.programs.niri.enable
  );
}
