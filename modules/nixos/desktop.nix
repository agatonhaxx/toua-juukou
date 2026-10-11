{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.toua;

  # Anything that has a graphical session, regardless of which one.
  graphical = cfg.desktop.gnome.enable || cfg.desktop.niri.enable;
in
{
  imports = [ inputs.catppuccin.nixosModules.catppuccin ];

  config = lib.mkMerge [
    {
      catppuccin = {
        enable = true;
        autoEnable = cfg.desktop.gnome.enable;
      };
    }

    # A greeter exists only to hand a session to someone, so it belongs to having
    # one. Without the `graphical` half a headless host takes the `"gdm"` default
    # and runs GDM, which nothing there can log in to and which, through
    # `services.graphical-desktop`, turns the `xdg` data back on that wall-e sets
    # false — a conflict the option cannot resolve on its own.
    (lib.mkIf (graphical && cfg.displayManager.greeter == "gdm") {
      services.displayManager.gdm.enable = true;
    })

    (lib.mkIf (graphical && cfg.displayManager.greeter == "dms") {
      services.displayManager.dms-greeter = {
        enable = true;

        # The greeter is a quickshell running in its own compositor, and the
        # module asserts that this one is enabled system-wide: home-manager's
        # niri does not count, which is why `toua.desktop.niri.enable` — not
        # `toua.programs.niri.enable` — is what has to be on here.
        compositor.name = "niri";

        # Copy the user's DankMaterialShell settings, colors and wallpaper into
        # the greeter's own directory at each start, so the login screen wears
        # the same theme as the session it is about to open.
        configHome = config.users.users.${cfg.primaryUser}.home;

        # A greeter that fails is a machine with no way in, and it runs before
        # there is a session to read the journal from.
        logs.save = true;
      };
    })

    (lib.mkIf cfg.desktop.gnome.enable {
      services.desktopManager.gnome.enable = true;

      # catppuccin/nix has no GNOME Shell or libadwaita module, so these two
      # ports are the full extent of its GNOME integration.
      catppuccin = {
        flavor = "mocha";
        accent = "mauve";
        cursors.enable = true;
      };
    })

    (lib.mkIf cfg.desktop.niri.enable {
      programs.niri.enable = true;
    })

    # Shared by any graphical session: X11 for XWayland and X-only apps, and
    # PipeWire, whose pulse interface replaces pulseaudio.
    (lib.mkIf graphical {
      # DDC/CI over the monitor's I2C bus: the shell drives external-monitor
      # brightness straight off /dev/i2c-N, and ddcutil and i2c-tools read the
      # same devices. The module loads i2c-dev and its udev rule hands them to
      # whoever holds the seat, so no group membership is needed for a local
      # session — the `i2c` group it also creates is for everyone else.
      hardware.i2c.enable = true;

      services = {
        xserver = {
          enable = true;

          xkb = {
            layout = "us";
            variant = "";
          };
        };

        pulseaudio.enable = false;
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };
      };
    })
  ];
}
