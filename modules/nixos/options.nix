{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  # Linux-only, so declared here: on Darwin these options do not exist and
  # setting one is an evaluation error rather than a silent no-op.
  options.toua = {
    desktop = {
      gnome.enable = mkEnableOption "Enable the GNOME desktop";

      # Registers the session with the display manager and its portals; the
      # window manager's own config.kdl is `toua.programs.niri.enable`.
      niri.enable = mkEnableOption "Register the niri session";
    };

    displayManager.gdm.enable = mkEnableOption "Enable the GDM display manager";

    # Only NixOS acts on this: ACME uses it as the contact address.
    # Required when toua.services.acme.enable is true; otherwise it may be null.
    email = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "someone@example.com";
      description = ''
        ACME contact email for this host's certificates. Required when
        toua.services.acme.enable is true. Kanidm user addresses are configured
        separately in services.kanidm.provision.persons.
      '';
    };

    domain = mkOption {
      type = types.str;
      default = "";
      example = "example.com";
      description = "Apex domain for services hosted by this machine.";
    };
  };
}
