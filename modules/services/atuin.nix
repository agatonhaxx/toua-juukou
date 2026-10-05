{
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../shared/lib.nix { inherit lib self; }) mkServiceOption;

  cfg = config.toua.services.atuin;
  toua = config.toua;
in
{
  options.toua.services.atuin = mkServiceOption "atuin" {
    port = 3004;
    host = "127.0.0.1";
    domain = "atuin.${toua.domain}";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = toua.domain != "";
        message = ''
          toua.services.atuin.enable needs toua.domain: atuin serves at
          atuin.<domain> and its certificate is issued for that name.
        '';
      }
    ];

    services.atuin = {
      enable = true;
      inherit (cfg) host port;
      openRegistration = false;
      maxHistoryLength = 1024 * 16;
    };

    security.acme.certs.${cfg.domain} = {
      dnsProvider = "cloudflare";
      credentialFiles."CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets.cloudflare-dns-token.path;
      group = "nginx";
    };

    services.nginx.virtualHosts.${cfg.domain} = {
      useACMEHost = cfg.domain;
      forceSSL = true;

      locations."/".proxyPass = "http://${cfg.host}:${toString cfg.port}";
    };
  };
}
