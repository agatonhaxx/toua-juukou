{
  lib,
  config,
  ...
}:
{
  programs.wezterm = lib.mkIf config.programs.wezterm.enable {
    settings = {
      window_decorations = "RESIZE";

      window_padding = {
        left = 4;
        right = 4;
        top = 4;
        bottom = 4;
      };
    };

    extraConfig = ''
      local config = wezterm.config_builder and wezterm.config_builder() or {}

      -- apply the catppuccin theme (variables injected by the catppuccin module preamble)
      dofile(catppuccin_plugin).apply_to_config(config, catppuccin_config)

      local act = wezterm.action

      config.keys = {
        -- vim-like pane navigation
        { key = "h", mods = "ALT", action = act.ActivatePaneDirection "Left" },
        { key = "j", mods = "ALT", action = act.ActivatePaneDirection "Down" },
        { key = "k", mods = "ALT", action = act.ActivatePaneDirection "Up" },
        { key = "l", mods = "ALT", action = act.ActivatePaneDirection "Right" },

        -- vim-like splits: "|" splits left/right, "-" splits top/bottom
        { key = "|", mods = "ALT", action = act.SplitHorizontal { domain = "CurrentPaneDomain" } },
        { key = "-", mods = "ALT", action = act.SplitVertical { domain = "CurrentPaneDomain" } },

        -- vim-like pane resizing
        { key = "h", mods = "ALT|SHIFT", action = act.AdjustPaneSize { "Left", 3 } },
        { key = "j", mods = "ALT|SHIFT", action = act.AdjustPaneSize { "Down", 3 } },
        { key = "k", mods = "ALT|SHIFT", action = act.AdjustPaneSize { "Up", 3 } },
        { key = "l", mods = "ALT|SHIFT", action = act.AdjustPaneSize { "Right", 3 } },

        -- tabs
        { key = "t", mods = "ALT", action = act.SpawnTab "CurrentPaneDomain" },
        { key = "n", mods = "ALT", action = act.ActivateTabRelative(1) },
        { key = "p", mods = "ALT", action = act.ActivateTabRelative(-1) },
        { key = "w", mods = "ALT", action = act.CloseCurrentTab { confirm = true } },

        -- panes
        { key = "x", mods = "ALT", action = act.CloseCurrentPane { confirm = true } },
        { key = "z", mods = "ALT", action = act.TogglePaneZoomState },
      }

      -- release left click to copy the selection to the system clipboard
      config.mouse_bindings = {
        {
          event = { Up = { streak = 1, button = "Left" } },
          mods = "NONE",
          action = wezterm.action.CompleteSelection "Clipboard",
        },
      }

      -- tab bar styling closer to a tmux status line
      config.use_fancy_tab_bar = false
      config.tab_bar_at_bottom = true
      config.hide_tab_bar_if_only_one_tab = false

      -- Ceiling on tab width, in cells (wezterm's default is 16). This is a
      -- cap, not a fixed width: the tab bar only ever shrinks a title to fit
      -- its tab, never pads one out, so a title shorter than this still
      -- renders at its natural width and only an overflowing one is cut here.
      config.tab_max_width = 22

      -- Date and clock at the right end of the bar. `%m/%d %H:%M` renders as
      -- `09/26 17:25`; wezterm.strftime formats via chrono, not C strftime, so
      -- the usual %m/%d/%H/%M specifiers carry over. The trailing space keeps
      -- the text off the window edge -- the status is right-aligned, and is
      -- clipped from the left if the bar runs out of room.
      --
      -- `update-status` is the current name; `update-right-status` still fires
      -- but is documented as deprecated. The interval is wezterm's default of
      -- 1000ms, restated here because the clock's tick rate depends on it.
      config.status_update_interval = 1000

      -- Kubernetes context, to the left of the clock. Polled on its own slower
      -- interval rather than every tick, since this spawns a process.
      --
      -- The `sh -c` wrapper is load-bearing, not decoration. Running kubectl
      -- directly raises a Lua error when kubectl is absent: the spawn failure
      -- is propagated out of Rust rather than returned as a false success flag
      -- (`run_child_process` ends in `map_err(mlua::Error::external)?`). An
      -- error escaping the handler would skip set_right_status entirely and
      -- take the clock down with it. Guarding in the shell means the spawn
      -- itself cannot fail -- so there is no need to depend on `pcall` working
      -- across mlua's async yield -- and a missing kubectl, or one with no
      -- current context, simply exits non-zero with no output.
      local k8s_poll_secs = 30
      local k8s_checked_at, k8s_context, k8s_namespace = nil, nil, nil

      local function k8s_status()
        local now = os.time()
        if k8s_checked_at and (now - k8s_checked_at) < k8s_poll_secs then
          return k8s_context, k8s_namespace
        end
        k8s_checked_at, k8s_context, k8s_namespace = now, nil, nil

        -- One call returns both fields; --minify narrows the config down to
        -- the current context. A context with no namespace leaves a bare `|`.
        local ok, stdout = wezterm.run_child_process {
          "sh",
          "-c",
          "command -v kubectl >/dev/null 2>&1 && exec kubectl config view --minify -o \"jsonpath={.current-context}|{.contexts[0].context.namespace}\"",
        }
        if not ok then
          return nil, nil
        end

        -- Split on the literal `|`. jsonpath emits no trailing newline, but
        -- trim both ends rather than depend on that.
        local ctx, ns = stdout:match("^(.-)|(.*)$")
        if not ctx then
          return nil, nil
        end
        ctx = ctx:gsub("^%s+", ""):gsub("%s+$", "")
        ns = ns:gsub("^%s+", ""):gsub("%s+$", "")
        if ctx == "" then
          return nil, nil
        end
        k8s_context = ctx
        k8s_namespace = ns ~= "" and ns or nil
        return k8s_context, k8s_namespace
      end

      wezterm.on("update-status", function(window, pane)
        local status = ""
        local ctx, ns = k8s_status()
        if ctx then
          local label = ns and (ctx .. " (" .. ns .. ")") or ctx
          status = wezterm.format {
            { Foreground = { AnsiColor = "Yellow" } },
            { Text = label },
            "ResetAttributes",
            { Text = "  " },
          }
        end
        window:set_right_status(status .. wezterm.strftime("%m/%d %H:%M") .. " ")
      end)

      return config
    '';
  };
}
