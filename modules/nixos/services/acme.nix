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

    # The Cloudflare API token lego authenticates DNS-01 challenges with.
    # Declared here rather than beside a certificate because more than one
    # service issues through the same provider; each one points at it with
    # `credentialFiles`. Left at the default ownership — the certificate
    # services load it through systemd's `LoadCredential`, which reads the file
    # as root and hands each unit a private copy.
    sops.secrets.cloudflare-dns-token = mkSecret {
      file = "cloudflare";
      key = "dns-api-token";
    };
  };

  # The DNS provider is *not* set here, deliberately. `security.acme.defaults`
  # would be the natural home for it, but nginx's own `enableACME` resets
  # `dnsProvider` to null on every certificate it creates, so a default set in
  # this file would be silently discarded. Each service sets the provider on its
  # own certificate and points its vhost at that certificate with `useACMEHost`
  # instead of `enableACME` — `kanidm.nix` is the worked example. Only
  # `dnsProvider` is reset; other defaults, `extraLegoFlags` among them,
  # survive, which is why the flag in `hosts/wall-e/default.nix` is set there.
}
