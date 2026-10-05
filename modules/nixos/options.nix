{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types;

  cfg = config.toua;
in
{
  # Declared here rather than in `modules/shared/options.nix` on purpose: these
  # are Linux-only concepts. Declaring them in the shared module would expose
  # them on Darwin too, where a host could set `desktop.niri.enable = true` and
  # have nothing happen. Here they simply do not exist off NixOS, so misuse is
  # an evaluation error rather than a silent no-op.
  options.toua = {
    desktop = {
      gnome.enable = mkEnableOption "Enable the GNOME desktop" // {
        default = cfg.profiles.desktop.enable;
      };

      # Registers the niri session with the display manager and sets up its
      # portals. The window manager's *user* configuration — config.kdl,
      # waybar, fuzzel, mako — is the separate `toua.programs.niri.enable`.
      niri.enable = mkEnableOption "Register the niri session" // {
        default = cfg.profiles.desktop.enable;
      };
    };

    displayManager.gdm.enable = mkEnableOption "Enable the GDM display manager" // {
      default = cfg.profiles.desktop.enable;
    };

    # Only NixOS acts on this — ACME uses it as the contact address, and kanidm
    # as the mail address of the user it provisions — so it is declared here
    # rather than in `modules/shared/options.nix`, per the split above. A `user/`
    # module wanting it on Darwin too (git's `user.email`) would make it shared.
    #
    # Optional: lego registers a placeholder when this is null and certificates
    # still issue, at the cost of a failing renewal announcing itself only by
    # the certificate going stale.
    email = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "someone@example.com";
      description = ''
        Personal email address. Used as the ACME contact for this host's
        certificates and as the mail address of the user kanidm provisions.
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
