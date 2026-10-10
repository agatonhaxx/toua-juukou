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

    (lib.mkIf cfg.displayManager.gdm.enable {
      services.displayManager.gdm.enable = true;
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
