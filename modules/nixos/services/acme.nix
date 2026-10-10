{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.toua.services.acme;
  toua = config.toua;

  inherit (import ../../shared/lib.nix { inherit lib self; }) mkSecret;
in
{
  options.toua.services.acme.enable = lib.mkEnableOption "the ACME service";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = toua.domain != "";
        message = "toua.services.acme.enable needs toua.domain.";
      }
      {
        assertion = toua.email != null;
        message = "toua.services.acme.enable needs toua.email.";
      }
    ];

    security.acme = {
      acceptTerms = true;
      defaults.email = toua.email;
    };

    # The Cloudflare token every service's DNS-01 challenge uses; left at the
    # default ownership because systemd's `LoadCredential` reads it as root.
    sops.secrets.cloudflare-dns-token = mkSecret {
      file = "cloudflare";
      key = "dns-api-token";
    };
  };

  # `security.acme.defaults` cannot carry the provider: nginx's own `enableACME`
  # resets `dnsProvider` per certificate, so each service sets its own.
}
