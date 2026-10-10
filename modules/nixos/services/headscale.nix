{
  config,
  lib,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; }) mkServiceOption mkWebService;

  cfg = config.toua.services.headscale;
  toua = config.toua;
  web = mkWebService {
    inherit config;
    name = "headscale";
  };

  # The vhosts this host serves to tailnet clients only. Their names live under
  # the MagicDNS base domain because nothing public resolves them: a client has
  # to resolve the name to this host's tailnet address, which is the same thing
  # nginx's own source check then relies on.
  tailnetOnly = lib.filterAttrs (
    _: service: (service.proxy or null) != null && service.proxy.access == "tailnet"
  ) config.toua.services;

  # One record per address per name. Tailscale carries A and AAAA only, so the
  # address itself decides which of the two it is.
  extraRecords = lib.concatMap (
    service:
    map (address: {
      name = service.domain;
      type = if lib.hasInfix ":" address then "AAAA" else "A";
      value = address;
    }) cfg.tailnetAddresses
  ) (lib.attrValues tailnetOnly);

  # IANA gives STUN 3478, and it is the port headscale's own example uses. The
  # relay answers on UDP, so it never passes through nginx.
  stunPort = 3478;
in
{
  options.toua.services.headscale =
    mkServiceOption "headscale" {
      # Not 8085's neighbour 8080: that one is qbittorrent's on baymax, and one
      # host running both should not be an argument.
      port = 8085;
      host = "127.0.0.1";
      domain = "headscale.${toua.domain}";
    }
    // {
      baseDomain = lib.mkOption {
        type = lib.types.str;
        default = "local.${toua.domain}";
        description = "The MagicDNS base domain; nodes answer to `<host>.<baseDomain>`, and the tailnet-only vhosts are published under it as extra records.";
      };

      tailnetAddresses = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "100.64.0.2"
          "fd7a:115c:a1e0::2"
        ];
        description = ''
          This host's own addresses on the tailnet, one extra record per
          tailnet-only vhost it fronts. headscale keeps a node's addresses in
          its database rather than deriving them from anything here, so the host
          that fronts those vhosts states them.
        '';
      };

      derp = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Run the embedded DERP relay, so the tailnet need not fall back to Tailscale's.";
        };

        regionId = lib.mkOption {
          type = lib.types.int;
          default = 999;
          description = "DERP region id. 900-999 is the range upstream leaves for private use.";
        };

        regionCode = lib.mkOption {
          type = lib.types.str;
          default = "hel";
          description = "Short DERP region code, as clients show it.";
        };

        regionName = lib.mkOption {
          type = lib.types.str;
          default = "Helsinki";
          description = "DERP region name, as clients show it.";
        };

        upstreamUrls = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "https://controlplane.tailscale.com/derpmap/default" ];
          description = "Foreign DERP maps to keep as a fallback for when this relay is unreachable; empty means none.";
        };
      };
    };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = web.assertions ++ [
          {
            assertion = cfg.baseDomain != cfg.domain;
            message = "toua.services.headscale.baseDomain must differ from its own domain: the MagicDNS names and the control API cannot share one name.";
          }
          {
            assertion = cfg.derp.regionId >= 900 && cfg.derp.regionId <= 999;
            message = "toua.services.headscale.derp.regionId belongs in 900-999, the range upstream leaves for private relays.";
          }
        ];
      }

      (lib.mkIf web.dependenciesEnabled {
        services.headscale = {
          enable = true;
          inherit (cfg) port;
          address = cfg.host;

          settings = {
            # Where nodes reach the API, and the name the embedded relay is
            # advertised under: nginx terminates TLS for both.
            server_url = "https://${cfg.domain}";

            # The search domain the client's resolver picks up is what makes a
            # bare `baymax` resolve on every node.
            dns = {
              magic_dns = true;
              base_domain = cfg.baseDomain;

              # Split DNS: a node keeps its own resolver and sends only names
              # under `baseDomain` to MagicDNS. Overriding would instead route
              # every node's lookups through a resolver named here, and the
              # nixpkgs module asserts that a config overriding local DNS carries
              # one — an upstream no machine of this fleet should depend on from
              # wherever it roams.
              override_local_dns = false;

              # What makes the tailnet-only vhosts resolve. MagicDNS answers them
              # with this host's tailnet address, so no public record exists for
              # them to be reached through. It belongs under `dns` rather than
              # beside it: `settings` is freeform, so a list there renders at the
              # top level of config.yaml, where headscale reads no records from
              # and reports nothing either.
              extra_records = extraRecords;
            };

            derp = {
              server = {
                enabled = cfg.derp.enable;

                # The `settings` submodule is freeform, so these keep
                # headscale's own spelling rather than the options'.
                region_id = cfg.derp.regionId;
                region_code = cfg.derp.regionCode;
                region_name = cfg.derp.regionName;
                stun_listen_addr = "0.0.0.0:${toString stunPort}";
              };

              urls = cfg.derp.upstreamUrls;
            };
          };
        };

        networking.firewall.allowedUDPPorts = lib.optionals cfg.derp.enable [ stunPort ];

        security.acme.certs.${cfg.domain} = web.certificate;

        services.nginx.virtualHosts.${cfg.domain} = {
          useACMEHost = cfg.domain;
          forceSSL = true;

          # Nodes hold a long-lived connection for control updates; the upgrade
          # headers are what let it through.
          locations."/" = {
            proxyPass = "http://${cfg.host}:${toString cfg.port}";
            proxyWebsockets = true;
          };

          # The relay's own stream, which buffering would hold frames back on.
          locations."/derp" = {
            proxyPass = "http://${cfg.host}:${toString cfg.port}";
            proxyWebsockets = true;
            extraConfig = "proxy_buffering off;";
          };
        };
      })
    ]
  );
}
