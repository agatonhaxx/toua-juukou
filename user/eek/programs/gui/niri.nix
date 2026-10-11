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
  # Everything below assumes DankMaterialShell: the `dms ipc` binds and the
  # `include optional=true "dms/*.kdl"` fragments have nothing to talk to
  # without it. So the session carries the shell rather than each niri host
  # opting in.
  #
  # A plain value, not `mkDefault`: every mirrored `toua.programs` entry from
  # `osConfig` is already `mkDefault`, so a default here would tie with the
  # host's own value and conflict instead of losing to it.
  toua.programs.dms.enable = lib.mkIf niriEnabled true;

  # The launcher the session runs is vicinae rather than DMS's spotlight, so its
  # daemon comes up with niri the same way — the unit is in
  # `modules/programs/gui/vicinae.nix`.
  toua.programs.vicinae.enable = lib.mkIf niriEnabled true;

  # Wayland/Linux-only, gated on the same flag as the session: otherwise a Darwin
  # host pulls in `niri` and friends. gamescope is not here: it belongs
  # to the gaming group, whose system wrapper carries cap_sys_nice, and a plain
  # package in this earlier PATH entry would shadow it.
  #
  # The bar, the notification daemon, idle/lock timers, clipboard history, the
  # wallpaper and the network, audio and logout applets are DankMaterialShell's
  # now — see ./dms.nix — so waybar, mako, swayidle, fuzzel, cliphist, swaybg,
  # networkmanagerapplet, pavucontrol and wlogout are gone from this list.
  home.packages = lib.mkIf niriEnabled (
    with pkgs;
    [
      # keep-sorted start
      fcitx5
      wl-clipboard # wl-copy/wl-paste: the wayland clipboard from a shell
      # keep-sorted end
    ]
  );

  xdg.configFile = lib.mkIf niriEnabled {
    "niri/config.kdl".text = ''
      // vim: ft=kdl

      layout {
          // You can tailor the gaps to fit dms spacing.
          gaps 5
      }

      input {
          keyboard {
              xkb {
                  layout "us,se,jp"
                  options "grp:ctrl_space_toggle,caps:escape"
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

      window-rule {
          match app-id=r#"^org\.gnome\."#
          draw-border-with-background false
          geometry-corner-radius 12
          clip-to-geometry true
      }

      window-rule {
          match app-id=r#"^org\.wezfurlong\.wezterm$"#
          match app-id="zen"
          draw-border-with-background false
      }

      window-rule {
          match is-active=false
          opacity 1.0
      }

      window-rule {
          geometry-corner-radius 12
          clip-to-geometry true
      }

      // Open DMS windows as floating by default (optional - DMS can manage this for you, see tip below)
      window-rule {
          match app-id=r#"^com\.danklinux\.dms$"#
          open-floating true
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
          XDG_CURRENT_DESKTOP "niri"
          ELECTRON_OZONE_PLATFORM_HINT "auto"
          MOZ_ENABLE_WAYLAND "1"
          QT_QPA_PLATFORM "wayland;xcb"
          NIXOS_OZONE_WL "1"
          NO_AT_BRIDGE "1" // silence "AT-SPI: Error retrieving accessibility bus address" for GTK apps (blueman, Firefox, etc.)
      }

      binds {
          // ── Launcher ──────────────────────────────────
          Mod+Return  { spawn "wezterm"; }
          // Vicinae, not DMS's spotlight: the daemon holds the window and this
          // only asks it to show. `vicinae` argues with nothing here — it has no
          // global shortcut of its own, so this bind is the only way in.
          Mod+Space   { spawn "vicinae" "toggle"; }
          Mod+Q       { close-window; }
          Mod+Slash   { show-hotkey-overlay; }

          // ── DankMaterialShell ────────────────────────
          // `dms ipc call <target> <function>`; targets and functions are listed
          // by `dms ipc list`. Where a key was free it is DMS's own preset, so
          // its docs and this file agree. Lock is the exception: its preset is
          // Mod+Alt+L, which niri's directional monitor binds below need, so it
          // sits one modifier away.
          Mod+V       { spawn "dms" "ipc" "call" "clipboard" "toggle"; }
          Mod+M       { spawn "dms" "ipc" "call" "processlist" "toggle"; }
          Mod+N       { spawn "dms" "ipc" "call" "notifications" "toggle"; }
          Mod+Shift+N { spawn "dms" "ipc" "call" "notepad" "toggle"; }
          Mod+Comma   { spawn "dms" "ipc" "call" "settings" "toggle"; }
          Mod+X       { spawn "dms" "ipc" "call" "powermenu" "toggle"; }
          Mod+Alt+N   { spawn "dms" "ipc" "call" "night" "toggle"; }
          Mod+Alt+Shift+L { spawn "dms" "ipc" "call" "lock" "lock"; }

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
          // Alt is what steps between the monitors themselves. These actions are
          // directional — they follow the physical arrangement rather than
          // monitor order — so with the TV to the left of DP-3, H lands on the
          // TV and L comes back.
          Mod+Alt+H { focus-monitor-left; }
          Mod+Alt+L { focus-monitor-right; }

          // Sending a thing across rather than looking across: the column
          // travels, matching Mod+Shift+H/L with Ctrl added for these keys.
          Mod+Ctrl+Alt+H { move-column-to-monitor-left; }
          Mod+Ctrl+Alt+L { move-column-to-monitor-right; }

          // ── Layout ───────────────────────────────────
          Mod+F    { fullscreen-window; }
          Mod+R    { switch-preset-column-width; }
          Mod+Shift+R { maximize-column; }

          // ── Screenshot ───────────────────────────────
          // DMS's capture rather than niri's built-in actions: `dms screenshot`
          // draws its own region selector and both writes the file and puts it
          // on the clipboard, which is the two steps the wayshot pipe to wl-copy
          // did by hand. The modes are subcommands, so `full` and `window` are
          // there for the taking.
          Print           { spawn "dms" "screenshot"; }
          Shift+Print     { spawn "dms" "screenshot" "full"; }
          Mod+Print       { spawn "dms" "screenshot" "--no-file"; }

          // ── Media keys ─────────────────────────────
          // All of these go through DMS rather than a helper binary: `audio`
          // moves the default sink, `brightness` the device its own daemon is
          // driving over DDC/backlight, and `mpris` acts on the player it holds
          // as active. So no wpctl, brightnessctl or playerctl in the bind —
          // and with the last two gone from `home.packages` above, nothing
          // else here could call them anyway.
          //
          // The `--player=spotatui` pinning went with playerctl: which player
          // these hit is now the pin in DMS's own Settings, under Media.
          XF86AudioRaiseVolume  { spawn "dms" "ipc" "call" "audio" "increment" "5"; }
          XF86AudioLowerVolume  { spawn "dms" "ipc" "call" "audio" "decrement" "5"; }
          XF86AudioMute         { spawn "dms" "ipc" "call" "audio" "mute"; }
          XF86MonBrightnessUp   { spawn "dms" "ipc" "call" "brightness" "increment" "5"; }
          XF86MonBrightnessDown { spawn "dms" "ipc" "call" "brightness" "decrement" "5"; }
          XF86AudioPlay         { spawn "dms" "ipc" "call" "mpris" "playPause"; }
          XF86AudioNext         { spawn "dms" "ipc" "call" "mpris" "next"; }
          XF86AudioPrev         { spawn "dms" "ipc" "call" "mpris" "previous"; }
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
      // block stay the only definition of the keyboard. So is `dms/wpblur.kdl`:
      // it only exists to place the blurred wallpaper layer within the backdrop,
      // and blur is not wanted here. The two `place-within-backdrop` layer-rules
      // it pairs with are gone from the `layer-rule` blocks above for the same
      // reason.
      include optional=true "dms/alttab.kdl"
      include optional=true "dms/colors.kdl"
      include optional=true "dms/cursor.kdl"
      include optional=true "dms/layout.kdl"
      include optional=true "dms/outputs.kdl"
      include optional=true "dms/windowrules.kdl"
    '';
  };
}
