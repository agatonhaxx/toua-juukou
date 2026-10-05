{
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../shared/lib.nix { inherit lib self; }) mkSecret mkServiceOption;

  cfg = config.toua.services.vaultwarden;
  kanidm = config.toua.services.kanidm;
  toua = config.toua;
in
{
  options.toua.services.vaultwarden = mkServiceOption "vaultwarden" {
    port = 3013;

    # nginx is the only thing that should reach vaultwarden, so bind tighter
    # than the `0.0.0.0` default.
    host = "127.0.0.1";

    domain = "vault.${toua.domain}";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = toua.domain != "";
        message = ''
          toua.services.vaultwarden.enable needs toua.domain: vaultwarden serves
          at vault.<domain> and its certificate is issued for that name.
        '';
      }
      {
        assertion = kanidm.enable;
        message = "toua.services.vaultwarden.enable needs toua.services.kanidm.enable for SSO.";
      }
      {
        assertion = toua.email != null;
        message = "toua.services.vaultwarden.enable needs toua.email for its Kanidm identity.";
      }
    ];

    # `ADMIN_TOKEN` lives here rather than in `config` below, which is written
    # into the world-readable Nix store. Password signups remain closed; new
    # identities instead come from Kanidm's Vaultwarden access group.
    sops = {
      secrets = {
        vaultwarden-env = mkSecret {
          file = "vaultwarden";
          key = "env";
          owner = "vaultwarden";
          group = "vaultwarden";
          mode = "400";
        };

        # Kanidm consumes the same value directly while Vaultwarden needs it in
        # dotenv syntax, so sops-nix renders the latter into the template below.
        vaultwarden-oauth2-client-secret = mkSecret {
          file = "kanidm";
          key = "oauth2-vaultwarden";
        };
      };

      templates."vaultwarden.env" = {
        owner = "vaultwarden";
        group = "vaultwarden";
        mode = "400";
        content = ''
          ${config.sops.placeholder.vaultwarden-env}
          SSO_CLIENT_SECRET=${config.sops.placeholder.vaultwarden-oauth2-client-secret}
        '';
      };
    };

    security.acme.certs.${cfg.domain} = {
      dnsProvider = "cloudflare";
      credentialFiles."CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets.cloudflare-dns-token.path;

      # nginx's service runs as user `nginx`, not root, and the acme module
      # asserts that every certificate a vhost serves is readable by the vhost's
      # group. A `useACMEHost` vhost is not given that group automatically the
      # way an `enableACME` one is, so it is set here.
      group = "nginx";
    };

    services.vaultwarden = {
      enable = true;
      environmentFile = config.sops.templates."vaultwarden.env".path;

      config = {
        DOMAIN = "https://${cfg.domain}";

        # This option replaces the module's default environment instead of
        # extending it, so the address and port it defaults to are restated.
        ROCKET_ADDRESS = cfg.host;
        ROCKET_PORT = cfg.port;

        # No self-service signup; accounts come from admin invitations.
        SIGNUPS_ALLOWED = false;
        INVITATIONS_ALLOWED = true;
        SHOW_PASSWORD_HINT = false;

        # Keep password login available until SSO has been exercised from all
        # clients. SSO users still have to know their Vaultwarden master
        # password; Kanidm replaces account authentication, not vault
        # encryption.
        SSO_ENABLED = true;
        SSO_ONLY = false;
        SSO_SIGNUPS_ALLOWED = true;
        SSO_SIGNUPS_MATCH_EMAIL = true;
        SSO_AUTHORITY = "https://${kanidm.domain}/oauth2/openid/vaultwarden";
        SSO_CLIENT_ID = "vaultwarden";
        SSO_SCOPES = "email profile";

        # stdout, which is the journal. EXTENDED_LOGGING adds timestamps and
        # module names to the lines.
        LOG_LEVEL = "warn";
        EXTENDED_LOGGING = true;
      };
    };

    services.nginx.virtualHosts.${cfg.domain} = {
      useACMEHost = cfg.domain;
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://${cfg.host}:${toString cfg.port}";

        # The web vault's notifications ride a websocket on the same path.
        proxyWebsockets = true;

        extraConfig = ''
          # vaultwarden authenticates on this header, and nginx drops it from
          # proxied requests unless told otherwise.
          proxy_pass_header Authorization;

          # Attachments are uploaded through here, and nginx's own 1M default
          # rejects anything larger before vaultwarden ever sees it.
          client_max_body_size 128m;
        '';
      };
    };
  };
}
