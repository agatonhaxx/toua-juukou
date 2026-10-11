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
  # Wayland/Linux-only, gated on the same flag as the session: otherwise a Darwin
  # host pulls in `niri` and friends. gamescope is not here: it belongs
  # to the gaming group, whose system wrapper carries cap_sys_nice, and a plain
  # package in this earlier PATH entry would shadow it.
  #
  # The bar, the notification daemon, idle/lock timers, clipboard history and the
  # wallpaper are DankMaterialShell's now — see ./dms.nix — so waybar, mako,
  # swayidle, fuzzel, cliphist and swaybg are gone from this list.
  home.packages = lib.mkIf niriEnabled (
    with pkgs;
    [
      # keep-sorted start
      brightnessctl # backlight control for dimming
      labwc
      networkmanagerapplet
      pavucontrol # volume control
      playerctl # MPRIS media key control
      wayshot # screenshot tool
      wl-clipboard # wl-copy/wl-paste: Mod+Print pipes a screenshot into the clipboard
      wlogout # styled logout menu
      xwayland-run
      # keep-sorted end
    ]
  );

  xdg.configFile = lib.mkIf niriEnabled {
    # Pull every window off the other monitors onto the focused one, bound to
    # Mod+Alt+G; nothing can detect the TV going to standby, so it is a keypress.
    "niri/gather-windows.sh" = {
      text = ''
        #!/bin/sh
        set -eu

        ws=$(niri msg --json workspaces)
        here=$(printf '%s' "$ws" | jq -r '.[] | select(.is_focused) | .output')

        # Every monitor keeps one empty workspace at the bottom, so the highest
        # index is that one; gathering there lands everything on a fresh desktop.
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
          mouse {
              // Flat is 1:1 motion: niri's accel-speed default of 0.0 leaves
              // libinput's flat profile with no constant factor to apply.
              accel-profile "flat"
          }
      }

      gestures {
        hot-corners {
          off
        }
      }

      // Spawn essential services at startup. DMS is not among them: its systemd
      // unit comes up with niri's own target — see ./dms.nix.
      spawn-at-startup "fcitx5"

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
          Mod+Space   { spawn "dms" "ipc" "call" "spotlight" "toggle"; }
          Mod+Q       { close-window; }
          Mod+Slash   { show-hotkey-overlay; }

          // ── DankMaterialShell ────────────────────────
          // `dms ipc call <target> <function>`; targets and functions are listed
          // by `dms ipc list`. Where a key was free it is DMS's own preset, so
          // its docs and this file agree.
          Mod+V       { spawn "dms" "ipc" "call" "clipboard" "toggle"; }
          Mod+M       { spawn "dms" "ipc" "call" "processlist" "toggle"; }
          Mod+N       { spawn "dms" "ipc" "call" "notifications" "toggle"; }
          Mod+Shift+N { spawn "dms" "ipc" "call" "notepad" "toggle"; }
          Mod+Comma   { spawn "dms" "ipc" "call" "settings" "toggle"; }
          Mod+X       { spawn "dms" "ipc" "call" "powermenu" "toggle"; }
          Mod+Alt+N   { spawn "dms" "ipc" "call" "night" "toggle"; }
          Mod+Alt+L   { spawn "dms" "ipc" "call" "lock" "lock"; }

          // Cycles the display profiles made in DMS's Display Config; this is
          // what kanshi's per-monitor profiles turned into.
          Mod+P       { spawn "dms" "ipc" "call" "outputs" "cycleProfile"; }

          // Blanks the panels without locking, for stepping away briefly.
          Mod+Shift+P { power-off-monitors; }

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
          // whichever monitor holds the focus; there is no 3 or 4.
          Mod+1 { focus-workspace 1; }
          Mod+2 { focus-workspace 2; }

          Mod+Shift+1 { move-window-to-workspace 1; }
          Mod+Shift+2 { move-window-to-workspace 2; }

          // ── Monitors ─────────────────────────────────
          // A second axis: J/K run out of desktops at the end of a monitor, so
          // Alt is what steps between the monitors themselves.
          Mod+Alt+H { focus-monitor-right; }
          Mod+Alt+L { focus-monitor-left; }

          // Sending a thing across rather than looking across: the column
          // travels, matching Mod+Shift+H/L with Ctrl added for these keys.
          Mod+Ctrl+Alt+H { move-column-to-monitor-right; }
          Mod+Ctrl+Alt+L { move-column-to-monitor-left; }

          // Nothing can watch for the TV dropping into standby: it holds the
          // HDMI link up, so the output still reads as connected.
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
          Mod+Shift+Q { spawn "wlogout"; }
      }

      // ── DankMaterialShell fragments ──────────────────
      // DMS writes these itself — `dms setup <name>` for upstream defaults, then
      // its Settings UI. They are deliberately not in the nix store: DMS has to
      // be able to write them, so they are the GUI's state, not this file's.
      // `optional=true` because niri refuses to start on a missing include, and
      // the first login happens before DMS has written any of them.
      //
      // Included last on purpose: a later include wins, so the Layout, Cursor,
      // Window Rules and Display Config tabs are the source of truth for what
      // they own — monitors included, which is how kanshi was retired.
      //
      // `dms/binds.kdl` is left out: its preset would collide with the binds
      // above. So is `dms/input.kdl`, so that the xkb layouts in the `input`
      // block stay the only definition of the keyboard.
      include optional=true "dms/alttab.kdl"
      include optional=true "dms/colors.kdl"
      include optional=true "dms/cursor.kdl"
      include optional=true "dms/layout.kdl"
      include optional=true "dms/outputs.kdl"
      include optional=true "dms/windowrules.kdl"
      include optional=true "dms/wpblur.kdl"
    '';
  };
}
