{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.toua.services.tailscale;
in
{
  options.toua.services.tailscale.enable = lib.mkEnableOption "the Tailscale service" // {
    default = config.toua.services.defaults.enable;
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      tailscale
    ];
    services.tailscale.enable = true;
  };
}
