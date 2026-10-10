{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib self; }) mkSecret mkServiceOption mkWebService;

  cfg = config.toua.services.kanidm;
  toua = config.toua;
  web = mkWebService {
    inherit config;
    name = "kanidm";
  };
  vaultwarden = config.toua.services.vaultwarden;

  # The Vaultwarden SSO group only exists when vaultwarden is enabled, so
  # membership is gated with it rather than naming a group that does not exist.
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

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = web.assertions;
      }
      (lib.mkIf web.dependenciesEnabled {
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

        security.acme.certs.${cfg.domain} = web.certificate // {
          # Kanidm reads TLS files at start, so a reissue needs a restart.
          reloadServices = [ "kanidm" ];
        };

        systemd.services.kanidm = {
          # The unit bind-mounts the TLS files, so they must exist before it
          # starts: without this ordering kanidm races acme and dies 226/NAMESPACE.
          after = [ "acme-${cfg.domain}.service" ];
          wants = [ "acme-${cfg.domain}.service" ];

          # Kanidm terminates TLS and reads the certificate in the nginx group.
          serviceConfig.SupplementaryGroups = [ "nginx" ];
        };

        services.kanidm = {
          # The stock package cannot read passwords out of files; this variant is
          # what lets `provision` take them from sops instead of the store.
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

        # `useACMEHost`, not `enableACME`: nginx references the certificate above
        # rather than creating its own, which keeps the DNS provider in place.
        services.nginx.virtualHosts.${cfg.domain} = {
          useACMEHost = cfg.domain;
          forceSSL = true;

          # Kanidm serves HTTPS itself; nginx does not verify upstreams by
          # default, which is what makes this work despite the certificate's name.
          locations."/".proxyPass = "https://${config.services.kanidm.server.settings.bindaddress}";
        };
      })
    ]
  );
}
