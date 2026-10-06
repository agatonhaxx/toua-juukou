{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) optionalAttrs;

  inherit (pkgs.stdenv.hostPlatform) isLinux;

  toua = config.toua;
  home = config.home.homeDirectory;
  xdgCfg = config.xdg;

  # Graphical settings are selected explicitly by profiles and can be overridden
  # by the host or user independently of individual application selections.
  # User directories and the X11 and Wine variables below are Linux-specific.
  desktop = isLinux && toua.graphical.enable;
in
{
  home.preferXdgDirectories = true;

  # `xdg.cacheHome`, `configHome`, `dataHome` and `stateHome` were set
  # explicitly in the original but are already home-manager's defaults, so they
  # are left alone here rather than restated.
  xdg = {
    userDirs = {
      enable = desktop;
      createDirectories = true;
      setSessionVariables = true;

      documents = "${home}/documents";
      download = "${home}/downloads";
      desktop = "${home}/desktop";
      videos = "${home}/media/videos";
      music = "${home}/media/music";
      pictures = "${home}/media/pictures";
      publicShare = "${home}/public/share";
      templates = "${home}/public/templates";
      projects = "${home}/dev";

      extraConfig = {
        SCREENSHOTS = "${xdgCfg.userDirs.pictures}/screenshots";
        DEV = "${home}/dev";
      };
    };

    mime.enable = desktop;
  };

  # Keeps the many tools that ignore XDG on their own out of `$HOME`. The list
  # is the one from xdg-ninja; entries in `user/eek/system/env.nix` that overlap are
  # commented out there.
  home.sessionVariables = {
    # Desktop
    KDEHOME = "${xdgCfg.configHome}/kde";
    # Programs
    LESSHISTFILE = "${xdgCfg.dataHome}/less/history";
    STEPPATH = "${xdgCfg.dataHome}/step";
    WAKATIME_HOME = "${xdgCfg.configHome}/wakatime";
    INPUTRC = "${xdgCfg.configHome}/readline/inputrc";
    PLATFORMIO_CORE_DIR = "${xdgCfg.dataHome}/platformio";
    DOTNET_CLI_HOME = "${xdgCfg.dataHome}/dotnet";
    MPLAYER_HOME = "${xdgCfg.configHome}/mplayer";
    SQLITE_HISTORY = "${xdgCfg.cacheHome}/sqlite_history";

    # Programming
    ANDROID_HOME = "${xdgCfg.dataHome}/android";
    ANDROID_USER_HOME = "${xdgCfg.dataHome}/android";
    GRADLE_USER_HOME = "${xdgCfg.dataHome}/gradle";
    IPYTHONDIR = "${xdgCfg.configHome}/ipython";
    JUPYTER_CONFIG_DIR = "${xdgCfg.configHome}/jupyter";
    GOPATH = "${xdgCfg.dataHome}/go";
    GOMODCACHE = "${xdgCfg.cacheHome}/go/pkg/mod";
    M2_HOME = "${xdgCfg.dataHome}/m2";
    CARGO_HOME = "${xdgCfg.dataHome}/cargo";
    RUSTUP_HOME = "${xdgCfg.dataHome}/rustup";
    STACK_ROOT = "${xdgCfg.dataHome}/stack";
    STACK_XDG = 1;
    NODE_REPL_HISTORY = "${xdgCfg.dataHome}/node_repl_history";
    NPM_CONFIG_CACHE = "${xdgCfg.cacheHome}/npm";
    NPM_CONFIG_TMP = "${xdgCfg.cacheHome}/npm/tmp";
    NPM_CONFIG_USERCONFIG = "${xdgCfg.configHome}/npm/config";
  }
  // optionalAttrs isLinux {
    XCOMPOSECACHE = "${xdgCfg.cacheHome}/X11/xcompose";
    ERRFILE = "${xdgCfg.cacheHome}/X11/xsession-errors";
    WINEPREFIX = "${xdgCfg.dataHome}/wine";
    CUDA_CACHE_PATH = "${xdgCfg.cacheHome}/nv";
  };

  xdg.configFile = {
    # Interpolated rather than escaped. The original wrote these as literal
    # `${cfg.dataHome}` text, which npm would have looked for as an environment
    # variable of that name; the paths are resolved here instead.
    "npm/npmrc".text = ''
      prefix=${xdgCfg.dataHome}/npm
      cache=${xdgCfg.cacheHome}/npm
      init-module=${xdgCfg.configHome}/npm/config/npm-init.js
    '';

    # Gives the Python REPL a persistent history under `$XDG_STATE_HOME`.
    "python/pythonrc".text = ''
      import os
      import atexit
      import readline
      from pathlib import Path

      if readline.get_current_history_length() == 0:

          state_home = os.environ.get("XDG_STATE_HOME")
          if state_home is None:
              state_home = Path.home() / ".local" / "state"
          else:
              state_home = Path(state_home)

          history_path = state_home / "python_history"
          if history_path.is_dir():
              raise OSError(f"'{history_path}' cannot be a directory")

          history = str(history_path)

          try:
              readline.read_history_file(history)
          except OSError: # Non existent
              pass

          def write_history():
              try:
                  readline.write_history_file(history)
              except OSError:
                  pass

          atexit.register(write_history)
    '';
  };
}
