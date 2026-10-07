{
  lib,
  config,
  pkgs,
  ...
}:
let
  niriEnabled = pkgs.stdenv.hostPlatform.isLinux && config.wayland.windowManager.niri.enable;
in
{
  # Everything below is Wayland/Linux-only. It has to be gated on the same flag
  # as the session itself, or a Darwin host pulls in packages that do not exist
  # there — `niri`, `swaybg`, `gamescope` and friends.
  home.packages = lib.mkIf niriEnabled (
    with pkgs;
    [
      # keep-sorted start
      brightnessctl # backlight control for dimming
      cliphist # clipboard history
      fuzzel # Wayland-native app launcher
      gamescope
      labwc
      mako # notification daemon
      networkmanagerapplet
      pavucontrol # volume control
      playerctl # MPRIS media key control
      swaybg # wallpaper daemon
      swayidle # idle management (dim + lock)
      wayshot # screenshot tool
      wlogout # styled logout menu
      xwayland-run
      # keep-sorted end
    ]
  );

  programs.waybar = lib.mkIf niriEnabled {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [
          "niri/workspaces"
          "niri/window"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "custom/kbdlayout"
          "pulseaudio"
          "cpu"
          "memory"
          "network"
          "tray"
        ];

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
          };
        };
        "niri/window" = {
          format = "{title}";
          max-length = 80;
        };
        clock = {
          format = "{:%A, %d %b %H:%M}";
          tooltip-format = "<tt>{calendar}</tt>";
        };
        pulseaudio = {
          format = "{icon}  {volume}%";
          format-muted = "";
          on-click-right = "pavucontrol";
          format-icons = {
            default = [
              ""
              "󰕾"
              ""
            ];
          };
        };
        network = {
          format-wifi = "󰖩  {signalStrength}%";
          on-click-right = "networkmanagerapplet";
          format-ethernet = "  {ifname}";
          format-disconnected = "󱚵 ";
        };
        cpu = {
          format = "  {usage}%";
        };
        memory = {
          format = "  {}%";
        };
        tray = {
          spacing = 20;
        };
        "custom/kbdlayout" = {
          exec = "${config.xdg.configHome}/waybar/kbdlayout.sh";
          exec-if = "niri msg keyboard-layouts >/dev/null 2>&1";
          interval = 1;
          format = " {}";
          tooltip-format = "Keyboard layout — click to cycle";
        };
      };
    };
    style = ''
      * {
        font-family: "FiraCode Nerd Font", monospace;
        font-size: 13px;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background-color: #1e1e2e;
        color: #cdd6f4;
      }

      #workspaces button {
        color: #6c7086;
        padding: 0 6px;
      }
      #workspaces button.active {
        color: #cdd6f4;
        border-bottom: 2px solid #cba6f7;
      }
      #workspaces button.urgent {
        color: #f38ba8;
      }

      #window {
        color: #a6adc8;
        padding: 0 10px;
      }

      #clock {
        color: #89b4fa;
        font-weight: bold;
      }

      #pulseaudio,
      #network,
      #cpu,
      #memory,
      #tray {
        color: #a6adc8;
        padding: 0 8px;
      }

      #pulseaudio.muted {
        color: #f38ba8;
      }

      #network.disconnected {
        color: #f38ba8;
      }

      #custom-kbdlayout {
        color: #a6adc8;
        padding: 0 8px;
      }

      tooltip {
        background: #313244;
        border: 1px solid #45475a;
      }
      tooltip label {
        color: #cdd6f4;
      }
    '';
  };

  xdg.configFile = lib.mkIf niriEnabled {
    # Keyboard layout indicator — parses niri msg keyboard-layouts
    "waybar/kbdlayout.sh" = {
      text = ''
        #!/bin/sh
        niri msg keyboard-layouts 2>/dev/null | awk '
          /^ \*/ {
            sub(/^ \*[ \t]*[0-9]+[ \t]*/, "")
            name = $0
            if (name ~ /English/)       print "EN"
            else if (name ~ /Swedish/)  print "SE"
            else if (name ~ /Japanese/) print "あ"
            else                        print substr(name, 1, 2)
            exit
          }
        '
      '';
      executable = true;
    };

    # Cycle to next keyboard layout — used by waybar on-click
    "waybar/kbdlayout-cycle.sh" = {
      text = ''
        #!/bin/sh
        # Get the number of layouts and current index, then cycle
        total=$(niri msg keyboard-layouts 2>/dev/null | grep -c '^[ *]')
        cur=$(niri msg keyboard-layouts 2>/dev/null | awk '/^ \*/ { print $2; exit }')
        if [ -n "$total" ] && [ -n "$cur" ]; then
          next=$(( (cur + 1) % total ))
          niri msg action switch-layout "$next"
        fi
      '';
      executable = true;
    };

    "fuzzel/fuzzel.ini".text = ''
      [main]
      font=FiraCode Nerd Font:size=18
      width=60
      dpi-aware=no
      lines=12
      horizontal-pad=30
      vertical-pad=30
      inner-pad=15

      [colors]
      background=1e1e2eff
      text=cdd6f4ff
      match=cba6f7ff
      selection=585b70ff
      selection-text=cdd6f4ff
      selection-match=cba6f7ff
      border=cba6f7ff
    '';

    # Mako notification daemon — Catppuccin Mocha theme + bluetooth filter
    "mako/config".text = ''
      # ── Global ──────────────────────────────────────
      sort=-time
      layer=overlay
      anchor=top-right
      font="FiraCode Nerd Font" 12
      width=400
      height=150
      margin=8
      padding=16
      border-size=2
      border-radius=8
      default-timeout=5000
      max-visible=5
      ignore-timeout=1

      # ── Colors (Catppuccin Mocha) ──────────────────
      background-color=#1e1e2eff
      text-color=#cdd6f4ff
      border-color=#cba6f7ff
      progress-color=over #89b4faff

      # ── Dismiss on right-click ─────────────────────
      on-button-right=dismiss

      # ── Ignore bluetooth/blueman notifications ─────
      [app-name=.blueman-applet-wrapped]
      invisible
    '';

    # Pull every window off the other monitors onto the focused one. Bound to
    # Mod+Alt+G in config.kdl; see the comment there for why this cannot be
    # automatic.
    "niri/gather-windows.sh" = {
      text = ''
        #!/bin/sh
        set -eu

        ws=$(niri msg --json workspaces)
        here=$(printf '%s' "$ws" | jq -r '.[] | select(.is_focused) | .output')

        # Every monitor always keeps one empty workspace at the bottom, so the
        # highest index is that one. Gathering there lands everything on a
        # fresh desktop instead of on top of what is already on screen.
        target=$(printf '%s' "$ws" | jq -r --arg o "$here" '[.[] | select(.output == $o) | .idx] | max')
        elsewhere=$(printf '%s' "$ws" | jq -c --arg o "$here" '[.[] | select(.output != $o) | .id]')

        # By id, so the focus never moves, and one window at a time: niri only
        # offers move-column-to-workspace for the focused column.
        niri msg --json windows \
          | jq -r --argjson ids "$elsewhere" '.[] | select(.workspace_id as $w | $ids | index($w)) | .id' \
          | while read -r id; do
              niri msg action move-window-to-workspace --window-id "$id" --focus false "$target" >/dev/null
            done
      '';
      executable = true;
    };

    "niri/config.kdl".text = ''
      // vim: ft=kdl

      input {
          keyboard {
              xkb {
                  layout "us,se,jp"
                  options "grp:ctrl_space_toggle,caps:swapescape"
              }
          repeat-delay 300
          repeat-rate 35
          }
          touchpad {
              tap
              natural-scroll
          }
      }

      // Monitors are kanshi's job, not this file's — see services.kanshi in
      // ./kanshi.nix. The `output` blocks that used to be here named bender's
      // connectors on every host, so baymax was left unconfigured.

      gestures {
        hot-corners {
          off
        }
      }
      // Spawn essential services at startup
      spawn-at-startup "waybar"
      // Pick a random wallpaper on each login from the collection checked out
      // under ~/dev/eek/wallpapers, skipping .git so swaybg is never handed a
      // file out of it. The collection is meant to become a flake input, so
      // that no host needs the checkout.
      spawn-sh-at-startup "swaybg -i \"$(find ${config.home.homeDirectory}/dev/eek/wallpapers -type f -not -path '*/.git/*' | shuf -n1)\""
      spawn-at-startup "fcitx5"
      // Idle management: dim after 15 min, lock (GDM) after 30 min
      spawn-at-startup "swayidle" "timeout" "900" "brightnessctl set 30%" "resume" "brightnessctl set 100%" "timeout" "1800" "loginctl lock-session"
      // Notification daemon
      spawn-at-startup "mako"

      // Clipboard history
      spawn-sh-at-startup "wl-paste --type text --watch cliphist store"
      spawn-sh-at-startup "wl-paste --type image --watch cliphist store"

      environment {
          DISPLAY ":0"
          MOZ_ENABLE_WAYLAND "1"
          QT_QPA_PLATFORM "wayland;xcb"
          NIXOS_OZONE_WL "1"
          NO_AT_BRIDGE "1" // silence "AT-SPI: Error retrieving accessibility bus address" for GTK apps (wlogout, etc.)
      }

      // Screenshot save path
      screenshot-path "${config.home.homeDirectory}/Pictures/Screenshots/screenshot-%Y-%m-%d_%H-%M-%S.png"

      binds {
          // ── Launcher ──────────────────────────────────
          Mod+Return  { spawn "wezterm"; }
          Mod+Space  { spawn "fuzzel"; }
          Mod+Q       { close-window; }
          Mod+Slash   { show-hotkey-overlay; }

          // ── Focus (vim-style hjkl) ───────────────────
          // H/L cross columns, which run horizontally. J/K cross workspaces,
          // which niri stacks vertically within each monitor, so the two axes
          // of the cluster match the two axes on screen.
          Mod+H { focus-column-left; }
          Mod+L { focus-column-right; }
          Mod+J { focus-workspace-down; }
          Mod+K { focus-workspace-up; }

          // ── Focus window within a column ─────────────
          Mod+Ctrl+J { focus-window-down; }
          Mod+Ctrl+K { focus-window-up; }

          // ── Move windows ─────────────────────────────
          Mod+Shift+H { move-column-left; }
          Mod+Shift+L { move-column-right; }
          Mod+Shift+J { move-window-down; }
          Mod+Shift+K { move-window-up; }

          // ── Workspaces (2 per monitor) ───────────────
          // Indices are per output, so 1 and 2 are the same two desktops on
          // whichever monitor holds the focus. There is no 3 or 4: niri's
          // workspaces are dynamic, and a third only exists once something
          // has been pushed past the second.
          Mod+1 { focus-workspace 1; }
          Mod+2 { focus-workspace 2; }

          Mod+Shift+1 { move-window-to-workspace 1; }
          Mod+Shift+2 { move-window-to-workspace 2; }

          // ── Monitors ─────────────────────────────────
          // A second, coarser axis: niri keeps a separate workspace list per
          // output, so J/K run out of desktops at the end of a monitor, and
          // Alt is what steps between the monitors themselves.
          Mod+Alt+H { focus-monitor-right; }
          Mod+Alt+L { focus-monitor-left; }

          // Sending a thing across, rather than looking across: the column
          // travels, matching Mod+Shift+H/L above, with Ctrl added to make
          // room for the monitor directions on the same two keys.
          Mod+Ctrl+Alt+H { move-column-to-monitor-right; }
          Mod+Ctrl+Alt+L { move-column-to-monitor-left; }

          // Nothing can watch for the TV dropping into standby: it holds the
          // HDMI link up, so the kernel and niri both still call the output
          // connected and its windows stay where they are. Gathering them
          // back onto the focused monitor is a keypress for that reason.
          Mod+Alt+G { spawn "${config.xdg.configHome}/niri/gather-windows.sh"; }

          // ── Layout ───────────────────────────────────
          Mod+F    { fullscreen-window; }
          Mod+R    { switch-preset-column-width; }
          Mod+Shift+R { maximize-column; }

          // ── Screenshot ───────────────────────────────
          Print           { screenshot; }
          Shift+Print     { screenshot-screen; }
          Mod+Print       { spawn-sh "wayshot --stdout | wl-copy"; }

          // ── Media keys ─────────────────────────────
          XF86AudioRaiseVolume  { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
          XF86AudioLowerVolume  { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
          XF86AudioMute         { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
          XF86MonBrightnessUp   { spawn "brightnessctl" "set" "5%+"; }
          XF86MonBrightnessDown { spawn "brightnessctl" "set" "5%-"; }
          XF86AudioPlay         { spawn "playerctl" "--player=spotatui" "play-pause"; }
          XF86AudioNext         { spawn "playerctl" "--player=spotatui" "next"; }
          XF86AudioPrev         { spawn "playerctl" "--player=spotatui" "previous"; }
          XF86PowerOff          { spawn "screenshot"; }

          // ── Session ──────────────────────────────────
          Mod+B       { spawn-sh "pkill waybar || waybar &"; }
          Mod+Shift+Q { spawn "wlogout"; }
      }

      layout {
          gaps 4
          default-column-width { proportion 0.5; }
          focus-ring {
              width 2
              active-color "#cba6f7"
              inactive-color "#45475a"
          }
          border {
              width 1
              active-color "#cba6f7"
              inactive-color "#313244"
          }
      }

      cursor {
          xcursor-theme "Adwaita"
          hide-when-typing true
      }

      // ── Window rules ─────────────────────────────────
      window-rule {
          match app-id="^firefox$"
          open-maximized true
      }

      window-rule {
          match title=r#".*Bitwarden.*"#
          open-floating true

          default-column-width { fixed 450; }
          default-window-height { fixed 700; }
      }

      window-rule {
          match app-id="^org.gnome.Nautilus$"
          open-maximized true
      }
    '';
  };
}
