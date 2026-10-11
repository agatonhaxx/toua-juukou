{
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib self; }) mkSecret mkServiceOption mkWebService;

  cfg = config.toua.services.radicale;
  toua = config.toua;

  # No vhost and no certificate here: `modules/nixos/services/proxy.nix` renders
  # both for anything carrying a `proxy`, which is how a service on this host is
  # fronted as well as one on another. What this file keeps is what that vhost
  # needs to be served at all.
  web = mkWebService {
    inherit config;
    name = "radicale";
  };
in
{
  options.toua.services.radicale = mkServiceOption "radicale" {
    # Upstream's default, and the port the vhost reaches this one on.
    port = 5232;

    # nginx is the only thing that should reach Radicale, so bind tighter than
    # the `0.0.0.0` default.
    host = "127.0.0.1";

    # Named under the MagicDNS base domain, like the endpoints wall-e fronts for
    # baymax: only MagicDNS resolves it, and it has no public record.
    domain = "dav.local.${toua.domain}";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = web.assertions ++ [
          {
            assertion = cfg.proxy != null;
            message = "toua.services.radicale is served through the fronting nginx, so the host that enables it states toua.services.radicale.proxy — loopback for the host running it.";
          }
        ];
      }

      (lib.mkIf web.dependenciesEnabled {
        # One `user:hash` line per user, and the file Radicale reads, rather than
        # a username list here to keep in step with it. Rotating a password needs
        # no restart: the file is re-read on every authentication.
        sops.secrets.radicale-htpasswd = mkSecret {
          file = "radicale";
          key = "htpasswd";
          owner = "radicale";
          group = "radicale";
          mode = "400";
        };

        services.radicale = {
          enable = true;

          settings = {
            # Stated so the port above is the one Radicale binds, not only the one
            # the vhost proxies to. The module binds loopback by itself when this
            # key is absent, and only then restricts the unit's sources — the
            # netfilter pair at the bottom of this file is that restriction,
            # restated for the named address.
            server.hosts = [ "${cfg.host}:${toString cfg.port}" ];

            auth = {
              # 3.5.0 changed this default from `none` to `denyall`, and the
              # module asserts that a configuration sets it either way.
              type = "htpasswd";
              htpasswd_filename = config.sops.secrets.radicale-htpasswd.path;

              # `autodetect` reads the same file; naming the algorithm fails
              # loudly on a line whose hash is not what it claims to be.
              htpasswd_encryption = "bcrypt";
            };

            # The unit's StateDirectory, and the only path it may write.
            storage.filesystem_folder = "/var/lib/radicale/collections";

            # Nobody shares a collection with anybody: each user sees their own
            # and no others.
            rights.type = "owner_only";

            # The collection UI at `/.web/`.
            web.type = "internal";
          };
        };

        systemd.services.radicale.serviceConfig = {
          IPAddressAllow = "localhost";
          IPAddressDeny = "any";
        };
      })
    ]
  );
}
