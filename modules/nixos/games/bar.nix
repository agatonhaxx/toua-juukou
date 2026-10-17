{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.toua.games.bar;
  user = config.toua.primaryUser;
  home = config.users.users.${user}.home;

  # "Latest" cannot be a build-time fetch: the release only exists at runtime.
  # A boot-time service runs this script as the primary user, which queries the
  # releases API and replaces the copy in ~/games when the tag changes.
  installer = pkgs.writeShellApplication {
    name = "byar-chobby-install";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];

    text = ''
      set -euo pipefail

      dest="$HOME/games"
      appimage="$dest/BYAR-Chobby.AppImage"
      version_file="$dest/.BYAR-Chobby.version"
      api="https://api.github.com/repos/beyond-all-reason/BYAR-Chobby/releases/latest"

      mkdir -p "$dest"

      release=$(curl -fsSL --proto '=https' --retry 5 --retry-delay 10 \
        -H 'Accept: application/vnd.github+json' "$api")

      tag=$(jq -r '.tag_name // empty' <<<"$release")
      url=$(jq -r 'first(.assets[] | select(.name | endswith(".AppImage")) | .browser_download_url) // empty' <<<"$release")

      if [ -z "$tag" ] || [ -z "$url" ]; then
        echo "BYAR-Chobby: no AppImage asset in the latest release" >&2
        exit 1
      fi

      installed=$(cat "$version_file" 2>/dev/null || true)
      if [ -f "$appimage" ] && [ "$installed" = "$tag" ]; then
        echo "BYAR-Chobby $tag is already installed"
        exit 0
      fi

      tmp=$(mktemp "$dest/.BYAR-Chobby.XXXXXX.AppImage")
      trap 'rm -f "$tmp"' EXIT

      echo "Installing BYAR-Chobby $tag"
      curl -fL --proto '=https' --retry 5 --retry-delay 10 -o "$tmp" "$url"
      chmod 0755 "$tmp"
      mv -f "$tmp" "$appimage"
      printf '%s\n' "$tag" > "$version_file"

      trap - EXIT
      echo "BYAR-Chobby $tag written to $appimage"
    '';
  };
in
{
  options.toua.games.bar.enable =
    lib.mkEnableOption "the latest Beyond All Reason (BYAR-Chobby) AppImage in ~/games";

  config = lib.mkIf cfg.enable {
    # `exec` rather than `oneshot`: systemd counts the service as started once
    # exec succeeds, so boot and switches do not wait for a large download. It
    # runs at every boot; a failed fetch retries until it succeeds.
    systemd.services.byar-chobby = {
      description = "Install the latest Beyond All Reason AppImage";

      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "exec";
        User = user;
        Environment = [ "HOME=${home}" ];
        ExecStart = lib.getExe installer;
        Restart = "on-failure";
        RestartSec = "5min";
      };
    };

    # The entry is system-wide, so any account on the host can start the game;
    # the AppImage it launches still lives in the primary user's home.
    environment.systemPackages = [
      (pkgs.makeDesktopItem {
        name = "byar-chobby";
        desktopName = "Beyond All Reason";
        genericName = "Real-time strategy game";
        comment = "Play Beyond All Reason";
        exec = "${pkgs.appimage-run}/bin/appimage-run ${home}/games/BYAR-Chobby.AppImage";
        icon = "applications-games";
        categories = [ "Game" ];
        terminal = false;
      })
    ];
  };
}
