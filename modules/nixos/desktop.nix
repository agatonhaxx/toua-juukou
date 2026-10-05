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
    (lib.mkIf cfg.displayManager.gdm.enable {
      services.displayManager.gdm.enable = true;
    })

    (lib.mkIf cfg.desktop.gnome.enable {
      services.desktopManager.gnome.enable = true;

      # Catppuccin for GNOME — icon + cursor themes applied to the GDM dconf
      # profile. catppuccin/nix has no libadwaita/GNOME Shell theming module;
      # these two ports are the full extent of its GNOME integration.
      catppuccin = {
        enable = true;
        flavor = "mocha";
        accent = "mauve";
        cursors.enable = true;
      };
    })

    (lib.mkIf cfg.desktop.niri.enable {
      programs.niri.enable = true;
    })

    # Session plumbing shared by any graphical session: X11 for XWayland and
    # X-only apps, and PipeWire for audio. PulseAudio is disabled because
    # PipeWire provides its interface.
    (lib.mkIf graphical {
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
