{
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib self; }) mkSecret mkServiceOption;

  cfg = config.toua.services.gatus;

  # Every endpoint alerts over ntfy unless it already names providers. The
  # thresholds and the resolved notification are set once, in the provider's
  # `default-alert`, which Gatus merges into each of these.
  withAlerts =
    endpoint:
    endpoint
    // {
      alerts = endpoint.alerts or [ { type = "ntfy"; } ];
    };
in
{
  options.toua.services.gatus =
    mkServiceOption "gatus" {
      port = 8080;

      # nginx is the only thing that should reach the status page, so bind
      # tighter than the `0.0.0.0` default.
      host = "127.0.0.1";
    }
    // {
      endpoints = lib.mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
        default = [ ];
        description = ''
          Gatus endpoints to watch. Each is passed through as written, with an
          ntfy alert added when it does not name `alerts` itself.
        '';
      };

      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = ''
          Further Gatus configuration, merged under the generated `web`,
          `alerting.ntfy` and `endpoints` settings, which take precedence.
        '';
      };
    };

  config = lib.mkIf cfg.enable {
    # SOPS renders the environment file as `gatus` before the unit starts, so
    # the name has to resolve. A static user of the unit's name is picked up
    # instead of a dynamic allocation, which keeps DynamicUser's hardening.
    users.groups.gatus = { };

    users.users.gatus = {
      isSystemUser = true;
      group = "gatus";
    };

    # The topic is the whole secret: anyone who knows it can read the alerts,
    # and it doubles as the subscription address in the ntfy app.
    sops = {
      secrets.gatus-ntfy-topic = mkSecret {
        file = "gatus";
        key = "ntfy-topic";
      };

      templates."gatus.env" = {
        owner = "gatus";
        group = "gatus";
        mode = "0400";

        # Gatus expands `${...}` in its configuration from the environment, and
        # the configuration itself is a world-readable store path.
        content = "GATUS_NTFY_TOPIC=${config.sops.placeholder.gatus-ntfy-topic}";
      };
    };

    services.gatus = {
      enable = true;
      environmentFile = config.sops.templates."gatus.env".path;

      settings = lib.recursiveUpdate cfg.settings {
        web = {
          address = cfg.host;
          port = cfg.port;
        };

        alerting.ntfy = {
          url = "https://ntfy.sh";
          topic = "\${GATUS_NTFY_TOPIC}";

          # Three consecutive failures before an alert, two successes before it
          # resolves, and a notice when it does, so a recovery is as visible as
          # the outage.
          default-alert = {
            enabled = true;
            failure-threshold = 3;
            success-threshold = 2;
            send-on-resolved = true;
          };
        };

        endpoints = map withAlerts cfg.endpoints;
      };
    };
  };
}
