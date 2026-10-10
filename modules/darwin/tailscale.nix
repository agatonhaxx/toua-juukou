{
  config,
  lib,
  ...
}:
let
  cfg = config.toua.services.tailscale;
in
{
  # nix-darwin's tailscale module has no `authKeyFile` and no `extraUpFlags`, so
  # there is nothing here to point at the control server — the one `tailscale
  # up` that does it has to be run by hand, and a warning saying so is as far as
  # the configuration can go. It deliberately leaves `overrideLocalDns` alone:
  # nix-darwin asserts `networking.dns == [ "100.100.100.100" ]` alongside it,
  # which would take this Mac's ordinary resolution down with it, and the Mac
  # only needs a tailnet source address, not MagicDNS.
  config = lib.mkIf (cfg.enable && cfg.loginServer != null) {
    warnings = [
      ''
        toua.services.tailscale.loginServer is set, but this Mac cannot be
        enrolled from the configuration. Run once, on the machine — logging out
        first if it is still on Tailscale's own control server, since a node
        keeps the server it registered with:

          sudo tailscale logout
          sudo tailscale up --login-server=${cfg.loginServer} \
            --auth-key=<its own preauthkey from secrets/services/tailscale.yaml>
      ''
    ];
  };
}
