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
    SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
  };
}
