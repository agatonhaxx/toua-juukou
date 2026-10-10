{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.toua.primaryUser;

  # nix-darwin leaves `home` null unless the host spells it out, so fall back to
  # the platform convention; the rendered path must be absolute at eval time.
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
  # The token is a secret, so it is rendered through `sops.templates` into a 0400
  # file in the user's home — the only sops scope this flake has.
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
