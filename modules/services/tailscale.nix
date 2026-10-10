{
  config,
  lib,
  ...
}:
let
  cfg = config.toua.services.tailscale;
in
{
  options.toua.services.tailscale = {
    enable = lib.mkEnableOption "the Tailscale service";

    loginServer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://headscale.huxe.eu";
      description = ''
        Control server to join instead of Tailscale's own. Enrolling a node
        against it is platform-specific, so this only records the address: the
        NixOS side reads it in `modules/nixos/services/tailscale.nix`, and
        `modules/darwin/tailscale.nix` says what the Mac's one manual step is.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Both platforms' modules install the client package themselves; all this
    # has to do is switch the daemon on.
    services.tailscale.enable = true;
  };
}
