{
  lib,
  config,
  pkgs,
  ...
}:
let
  # Same gate as dms.nix and niri.nix: the launcher is a session client, and the
  # systemd user service below is the Linux unit upstream ships. A Darwin host
  # gets the cask from modules/darwin, not this.
  isLinux = pkgs.stdenv.hostPlatform.isLinux;

  enabled = isLinux && config.toua.programs.vicinae.enable;
in
{
  # Outside `enabled` on purpose: inside it, the assertion would only ever
  # evaluate on the platform it checks for, and so never fire.
  assertions = [
    {
      assertion = isLinux || !config.toua.programs.vicinae.enable;
      message = "toua.programs.vicinae.enable is only supported on Linux";
    }
  ];

  # The daemon owns the launcher window and the CLI reaches it over IPC, so
  # `vicinae toggle` — what the niri bind spawns — is a no-op without it.
  #
  # Upstream ships this unit as `share/systemd/user/vicinae.service`; it is
  # repeated rather than taken from the package because that copy runs a bare
  # `vicinae` from PATH, and the store path is what pins the binary here.
  systemd.user.services.vicinae = lib.mkIf enabled {
    Unit = {
      Description = "Vicinae Launcher Daemon";
      Documentation = "https://docs.vicinae.com";

      # DMS's own unit hangs off the same target: niri brings it up, and before
      # that there is no display to put a launcher on.
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      Requires = [ "dbus.socket" ];
    };

    Service = {
      Type = "simple";

      # `--replace` so a restart takes over an instance left behind by a crash
      # of the unit instead of dying on the occupied socket.
      ExecStart = "${lib.getExe pkgs.vicinae} server --replace";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";

      # Upstream's own policy: restart forever, but a minute apart, so a broken
      # configuration cannot spin. Without the interval systemd would hit the
      # start limit and give up on the launcher for the rest of the session.
      Restart = "always";
      RestartSec = 60;
      KillMode = "process";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  # The CLI is what the niri bind calls, so both halves ship together.
  home.packages = lib.mkIf enabled [ pkgs.vicinae ];
}
