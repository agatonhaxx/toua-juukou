{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (import ../shared/lib.nix { inherit lib self; }) mkSecret mkServiceOption;

  cfg = config.toua.services.kanidm;
  toua = config.toua;
  vaultwarden = config.toua.services.vaultwarden;

  # Every provisioned person joins the Vaultwarden SSO group, but that group is
  # only created when vaultwarden is enabled, so membership is gated with it
  # rather than referencing a group that does not exist.
  vaultwardenGroups = lib.optional vaultwarden.enable "vaultwarden.access";

  # `cfg.domain` is set by the option below, which is what this certificate is
  # issued for.
  cert = config.security.acme.certs.${cfg.domain};
in
{
  options.toua.services.kanidm = mkServiceOption "kanidm" {
    port = 3010;
    host = "127.0.0.1";
    domain = "sso.${toua.domain}";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = toua.domain != "";
        message = ''
          toua.services.kanidm.enable needs toua.domain: kanidm serves at
          sso.<domain> and its certificate is issued for that name.
        '';
      }
    ];

    sops.secrets = {
      kanidm-admin-password = mkSecret {
        file = "kanidm";
        key = "admin-password";
        owner = "kanidm";
        group = "kanidm";
        mode = "440";
      };

      kanidm-idm-admin-password = mkSecret {
        file = "kanidm";
        key = "idm-admin-password";
        owner = "kanidm";
        group = "kanidm";
        mode = "440";
      };
    }
    // lib.optionalAttrs vaultwarden.enable {
      kanidm-oauth2-vaultwarden = mkSecret {
        file = "kanidm";
        key = "oauth2-vaultwarden";
        owner = "kanidm";
        group = "kanidm";
        mode = "440";
      };
    };

    security.acme.certs.${cfg.domain} = {
      dnsProvider = "cloudflare";

      # lego reads the token through a systemd credential, and the `_FILE`
      # suffix is what makes it a path to the token rather than the token.
      credentialFiles."CLOUDFLARE_DNS_API_TOKEN_FILE" = config.sops.secrets.cloudflare-dns-token.path;

      # The recursive half of lego's propagation check is turned off in the host
      # file, through `security.acme.defaults`, for every certificate on the box.

      # kanidm terminates TLS itself rather than letting nginx do it, so the key
      # has to be readable by its user. The certificate stays in the nginx group
      # — nginx's service runs as user `nginx`, not root, and the acme module
      # asserts that every certificate a vhost serves is readable by it — so
      # kanidm joins that group below rather than the other way round.
      group = "nginx";

      # kanidm reads the TLS files at start, so a reissue needs a restart.
      reloadServices = [ "kanidm" ];
    };

    systemd.services.kanidm = {
      # The unit bind-mounts the TLS files into its mount namespace, so they must
      # exist before it starts: without this ordering kanidm races acme on first
      # boot and dies with 226/NAMESPACE.
      after = [ "acme-${cfg.domain}.service" ];
      wants = [ "acme-${cfg.domain}.service" ];

      serviceConfig.SupplementaryGroups = [ "nginx" ];
    };

    services.kanidm = {
      # The stock package cannot read passwords out of files. This variant is
      # what lets `provision` take them from sops rather than holding them in
      # the Nix store.
      package = pkgs.kanidmWithSecretProvisioning_1_11;

      client = {
        enable = true;
        settings.uri = "https://${cfg.domain}";
      };

      server = {
        enable = true;

        settings = {
          version = "2";
          inherit (cfg) domain;
          origin = "https://${cfg.domain}";
          bindaddress = "${cfg.host}:${toString cfg.port}";
          ldapbindaddress = "${cfg.host}:3636";
          tls_chain = "${cert.directory}/fullchain.pem";
          tls_key = "${cert.directory}/key.pem";
        };
      };

      provision = {
        enable = true;

        adminPasswordFile = config.sops.secrets.kanidm-admin-password.path;
        idmAdminPasswordFile = config.sops.secrets.kanidm-idm-admin-password.path;

        persons = {
          glenn = {
            displayName = "glenn";
            legalName = "glenn";
            mailAddresses = [ "glenn@huxe.eu" ];
            groups = vaultwardenGroups;
          };
          eek = {
            displayName = "eek";
            legalName = "eek";
            mailAddresses = [ "eek@huxe.eu" ];
            groups = vaultwardenGroups;
          };
        };

        groups = lib.optionalAttrs vaultwarden.enable {
          "vaultwarden.access" = { };
        };

        systems.oauth2 = lib.optionalAttrs vaultwarden.enable {
          vaultwarden = {
            displayName = "Vaultwarden";
            originUrl = "https://${vaultwarden.domain}/identity/connect/oidc-signin";
            originLanding = "https://${vaultwarden.domain}/";
            basicSecretFile = config.sops.secrets.kanidm-oauth2-vaultwarden.path;
            preferShortUsername = true;
            scopeMaps."vaultwarden.access" = [
              "openid"
              "email"
              "profile"
            ];
          };
        };
      };
    };

    # `useACMEHost` rather than `enableACME`: nginx then references the
    # certificate above instead of creating one of its own, which is what keeps
    # the Cloudflare DNS provider in place.
    services.nginx.virtualHosts.${cfg.domain} = {
      useACMEHost = cfg.domain;
      forceSSL = true;

      # Kanidm serves HTTPS itself, so the upstream scheme is https. nginx does
      # not verify upstream certificates by default, which is what makes this
      # work despite the name on kanidm's certificate being sso.<domain> rather
      # than the 127.0.0.1 it is reached on.
      locations."/".proxyPass = "https://${config.services.kanidm.server.settings.bindaddress}";
    };
  };
}
