{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.toua.primaryUser;

  # NixOS defaults a normal user's `home` to `/home/<name>`, but nix-darwin
  # leaves it null unless the host spells it out, so fall back to the macOS
  # convention there. The rendered path has to be absolute at evaluation time.
  userHome =
    let
      configured = config.users.users.${user}.home;
    in
    if configured == null then
      (if pkgs.stdenv.hostPlatform.isDarwin then "/Users" else "/home") + "/${user}"
    else
      configured;
in
{
  # DeepSeek serves an Anthropic-compatible API, so pointing Claude Code at it
  # is a matter of environment variables. They are rendered into a file rather
  # than exported from the shell profile because the auth token is a secret:
  # `sops.templates` is the only mechanism here that substitutes a placeholder,
  # and the rendered copy is written 0400 to the user's home, never the store.
  #
  # Declared at system scope because that is the only sops scope this flake
  # has — home-manager reaches the result through the same rendered file.
  config = lib.mkIf config.toua.programs.claude-code.enable {
    sops.secrets.deepseek-api-key = {
      sopsFile = ../../secrets/eek.yaml;
      # sops-nix addresses nested YAML with `/`.
      key = "deepseek/api-key";
      owner = user;
    };

    sops.templates."deepseek-env" = {
      path = "${userHome}/.config/deepseek/env.sh";
      owner = user;
      mode = "0400";
      content = ''
        export ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
        export ANTHROPIC_AUTH_TOKEN=${config.sops.placeholder.deepseek-api-key}
        export ANTHROPIC_MODEL=deepseek-flash[1m]
        export ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-flash[1m]
        export ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-flash[1m]
        export ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-flash
        export CLAUDE_CODE_SUBAGENT_MODEL=deepseek-flash
        export CLAUDE_CODE_EFFORT_LEVEL=high
        export CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432
        export CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=15
      '';
    };
  };
}
