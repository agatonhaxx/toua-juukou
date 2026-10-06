{
  lib,
  config,
  pkgs,
  ...
}:
{
  # TODO make this my own envvars
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";

    GITDIR = "$HOME/dev";
    HIVEMIND = "$GITDIR/eek/hive-mind";
    NVIM_CONFIG = "$GITDIR/eek/nvim-eek";
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    # Placeholder: Bitwarden desktop's SSH agent socket. Confirm the group
    # container path against your install before relying on it.
    SSH_AUTH_SOCK = "${config.home.homeDirectory}/Library/Group Containers/REPLACE-ME.com.bitwarden.desktop/agent.sock";
  };
}
