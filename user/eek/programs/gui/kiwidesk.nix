{
  lib,
  pkgs,
  config,
  ...
}:
let
  enabled = pkgs.stdenv.hostPlatform.isDarwin && config.toua.programs.kiwidesk.enable;
  colors = config.palette.mocha.colors;
  appRules = {
    "com.github.wez.wezterm" = 1;
    "com.google.Chrome" = 1;
    "org.mozilla.firefox" = 1;
    "com.microsoft.Outlook" = 2;
    "com.microsoft.teams2" = 2;
    "io.github.aedev.flow.desktop.beta" = 3;
  };
in
{
  xdg.configFile = lib.mkIf enabled {
    # Ctrl+Alt is the macOS equivalent of niri's Mod key. Declaring bindings in
    # init.lua makes the shortcut set declarative; KiwiDesk will show the file
    # in its Settings editor instead of maintaining a separate gui.json keymap.
    # Do not adopt into the visual editor: it replaces init.lua with a
    # commented backup and cannot preserve these Lua closures and helpers.
    "KiwiDesk/init.lua".text = ''
      local mod = "ctrl+alt+"
      local move = "ctrl+alt+shift+"

      local main_space = 1
      local mac_space = 2
      local space_count = 3
      local width_steps = { "30%", "50%", "70%" }
      local width_step_by_space = {}

      local function bind(key, action)
        KiwiDesk.bind(key, action)
      end

      local function active_space()
        local state = KiwiDesk.get_state()
        return state and state.active_space or nil
      end

      local function focus_adjacent_space(offset)
        local space = tonumber(active_space())
        if space == nil then
          return
        end

        local target = space + offset
        if target >= 1 and target <= space_count then
          KiwiDesk.focus_space(target)
        end
      end

      local function cycle_width()
        local space = active_space()
        if space == nil then
          return
        end

        local key = tostring(space)
        local step = (width_step_by_space[key] or 0) % #width_steps + 1
        width_step_by_space[key] = step
        scroll.set_slot_size_override(space, width_steps[step])
      end

      local function fill_width()
        local space = active_space()
        if space == nil then
          return
        end

        width_step_by_space[tostring(space)] = 0
        scroll.set_slot_size_override(space, "100%")
      end

      -- Hide both KiwiShelf bars on every display.
      space_bar.set_enabled(false)
      monocle.set_app_bar_enabled(false)
      scroll.set_app_bar_enabled(false)

      -- Catppuccin Mocha
      border.set_enabled(true)
      border.set_width(4)
      border.set_focused_color("${colors.mauve.hex}")
      border.set_unfocused_enabled(true)
      border.set_unfocused_color("${colors.surface1.hex}")

      kiwishelf.set_item_color("${colors.subtext0.hex}")
      kiwishelf.set_fill_color("${colors.base.hex}E6")
      kiwishelf.set_active_item_color("${colors.mauve.hex}")
      kiwishelf.set_highlight_color("${colors.surface1.hex}")
      kiwishelf.set_hover_fill_color("${colors.surface0.hex}")
      kiwishelf.set_hover_item_color("${colors.text.hex}")
      kiwishelf.set_group_badge_color("${colors.surface2.hex}")
      kiwishelf.set_group_badge_text_color("${colors.text.hex}")

      sticky.set_color("${colors.yellow.hex}")
      floating.set_color("${colors.blue.hex}")

      -- A lone scrolling window should consume the otherwise unused width.
      -- KiwiDesk does not redistribute leftover width between multiple slots.
      scroll.set_fill_when_alone(true)

      app_rules = {
        ${lib.concatStringsSep "\n        " (
          lib.mapAttrsToList (app: space: ''["${app}"] = ${toString space},'') appRules
        )}
      }

      -- Launchers
      bind(mod .. "return", function()
        KiwiDesk.exec([[osascript -e 'tell application "System Events" to keystroke space using command down']])
      end)
      bind(mod .. "space", function()
        KiwiDesk.pull_or_spawn("com.github.wez.wezterm")
      end)

      -- Window actions
      bind(mod .. "q", function()
        KiwiDesk.exec([[osascript -e 'tell application "System Events" to keystroke "w" using command down']])
      end)
      bind(mod .. "f", function()
        KiwiDesk.exec([[osascript -e 'tell application "System Events" to keystroke "f" using {control down, command down}']])
      end)
      bind(mod .. "slash", function()
        KiwiDesk.show_shortcuts()
      end)
      bind(mod .. "comma", function()
        KiwiDesk.open_settings()
      end)

      -- H/L focus windows; J/K navigate the ordered spaces across displays.
      for key, direction in pairs({
        h = "left",
        l = "right",
      }) do
        local focus_key = key
        local focus_direction = direction
        bind(mod .. focus_key, function()
          KiwiDesk.focus(focus_direction)
        end)
      end

      bind(mod .. "j", function()
        focus_adjacent_space(1)
      end)
      bind(mod .. "k", function()
        focus_adjacent_space(-1)
      end)

      -- Move: KiwiDesk calls this swapping with the adjacent tiled window.
      for key, direction in pairs({
        h = "left",
        j = "down",
        k = "up",
        l = "right",
      }) do
        local swap_key = key
        local swap_direction = direction
        bind(move .. swap_key, function()
          KiwiDesk.swap(swap_direction)
        end)
      end

      -- Move the focused window between displays and keep following it.
      bind(move .. "left", function()
        KiwiDesk.move_to_space_and_follow(main_space)
      end)
      bind(move .. "right", function()
        KiwiDesk.move_to_space_and_follow(mac_space)
      end)

      -- Scrolling-layout widths: cycle 30% -> 50% -> 70%, or fill the screen.
      bind(mod .. "r", cycle_width)
      bind(move .. "r", fill_width)

      -- KiwiDesk Spaces correspond to niri workspaces for these bindings.
      for space = 1, space_count do
        local target_space = space
        bind(mod .. tostring(target_space), function()
          KiwiDesk.focus_space(target_space)
        end)
        bind(move .. tostring(target_space), function()
          KiwiDesk.move_to_space(target_space)
        end)
      end

      -- Reapply Starter after display changes, then persist the display pins
      -- in the profile so profile loading cannot replace them.
      local function load_starter()
        local monitors = KiwiDesk.list_monitors()
        local philips, mac
        for _, monitor in ipairs(monitors) do
          if not philips and monitor.name:match("^PHL ") then
            philips = monitor
          elseif monitor.name == "Built-in Retina Display" then
            mac = monitor
          end
        end

        local fallback = mac or philips or monitors[1]
        if not fallback then
          return
        end

        KiwiDesk.load_profile("Starter")
        KiwiDesk.pin_space_to_display(1, (philips or fallback).fingerprint)
        KiwiDesk.pin_space_to_display(2, (mac or fallback).fingerprint)
        KiwiDesk.pin_space_to_display(3, (mac or fallback).fingerprint)
        KiwiDesk.save_profile("Starter")
        KiwiDesk.set_default_profile("Starter")
      end

      -- The callback runs after init.lua's base state and automatic profiles.
      KiwiDesk.exec("true", load_starter)
      KiwiDesk.on("monitor_change", load_starter)
    '';
  };

  # Profiles override init.lua. Enforce Starter's scrolling layouts, space
  # list, app assignments, display pins, hidden bars and Catppuccin colors.
  home.activation.kiwideskStarterColors = lib.mkIf enabled (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      profile_path=${lib.escapeShellArg "${config.xdg.configHome}/KiwiDesk/profiles/Starter.json"}

      if [[ ! -f "$profile_path" ]]; then
        mkdir -p "$(dirname "$profile_path")"
        printf '%s\n' '{"format":15,"name":"Starter","space_modes":{"1":"scrolling","2":"scrolling","3":"scrolling"}}' > "$profile_path"
      fi

      if [[ -f "$profile_path" ]]; then
        temporary_path="$(mktemp "$profile_path.tmp.XXXXXX")"

        ${pkgs.jq}/bin/jq \
          --argjson app_rules ${lib.escapeShellArg (builtins.toJSON appRules)} \
          --arg base "${colors.base.hex}E6" \
          --arg blue "${colors.blue.hex}" \
          --arg mauve "${colors.mauve.hex}" \
          --arg subtext0 "${colors.subtext0.hex}" \
          --arg surface0 "${colors.surface0.hex}" \
          --arg surface1 "${colors.surface1.hex}" \
          --arg surface2 "${colors.surface2.hex}" \
          --arg text "${colors.text.hex}" \
          --arg yellow "${colors.yellow.hex}" \
          '
            .default = true |
            .starter_setup = false |
            .spaces = ["1", "2", "3"] |
            .fallback_space = "1" |
            .main_spaces = [] |
            .app_rules = ($app_rules | map_values(tostring)) |
            .space_modes = {"1": "scrolling", "2": "scrolling", "3": "scrolling"} |
            .monitor_sets |= ((. // []) | map(
              .space_monitor_map = (
                .monitors as $monitors |
                [$monitors[] | select(startswith("PHL "))][0] as $philips |
                [$monitors[] | select(startswith("Built-in Retina Display:"))][0] as $mac |
                ($mac // $philips // $monitors[0]) as $fallback |
                if $fallback then {
                  "1": ($philips // $fallback),
                  "2": ($mac // $fallback),
                  "3": ($mac // $fallback)
                } else {} end
              )
            )) |
            .settings.space_bar.enabled = false |
            .settings.layout.monocle.app_bar.enabled = false |
            .settings.layout.scroll.app_bar.enabled = false |
            .settings.border.enabled = true |
            .settings.border.width = 4 |
            .settings.border.focused_color = $mauve |
            .settings.border.unfocused_enabled = true |
            .settings.border.unfocused_color = $surface1 |
            .settings.kiwishelf.item_color = $subtext0 |
            .settings.kiwishelf.fill_color = $base |
            .settings.kiwishelf.active_item_color = $mauve |
            .settings.kiwishelf.highlight_color = $surface1 |
            .settings.kiwishelf.hover_fill_color = $surface0 |
            .settings.kiwishelf.hover_item_color = $text |
            .settings.kiwishelf.group_badge_color = $surface2 |
            .settings.kiwishelf.group_badge_text_color = $text |
            .settings.sticky.color = $yellow |
            .settings.floating.color = $blue
          ' "$profile_path" > "$temporary_path"

        mv "$temporary_path" "$profile_path"

        if [[ -S ${lib.escapeShellArg "${config.xdg.configHome}/KiwiDesk/KiwiDesk.sock"} ]] \
          && command -v kiwidesk >/dev/null 2>&1; then
          if ! kiwidesk reload_config; then
            echo "warning: could not reload KiwiDesk after applying the declarative colors" >&2
          fi
        fi
      fi
    ''
  );
}
