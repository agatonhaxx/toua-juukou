{
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../shared/lib.nix { inherit lib self; }) mkServiceOption mkWebService;

  cfg = config.toua.services.atuin;
  toua = config.toua;
  web = mkWebService {
    inherit config;
    name = "atuin";
  };
in
{
  options.toua.services.atuin = mkServiceOption "atuin" {
    port = 3004;
    host = "127.0.0.1";
    domain = "atuin.${toua.domain}";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = web.assertions;
      }
      (lib.mkIf web.dependenciesEnabled {
        services.atuin = {
          enable = true;
          inherit (cfg) host port;
          openRegistration = false;
          maxHistoryLength = 1024 * 16;
        };

        security.acme.certs.${cfg.domain} = web.certificate;

        services.nginx.virtualHosts.${cfg.domain} = {
          useACMEHost = cfg.domain;
          forceSSL = true;

          locations."/".proxyPass = "http://${cfg.host}:${toString cfg.port}";
        };
      })
    ]
  );
}
