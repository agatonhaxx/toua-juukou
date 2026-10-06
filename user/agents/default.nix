{
  config,
  lib,
  osConfig,
  ...
}:
let
  toua = osConfig.toua.programs;
  # Both the rules file and the hook are only meaningful where the agent
  # programs themselves are installed.
  agentsEnabled = toua.agents.enable;

  # Every agent in `agentProgramNames` exposes the same prompt-submission event
  # and the same `systemMessage` output shape, so one handler entry serves them
  # all. Adding a third agent means adding its wiring below.
  factHook = [
    {
      hooks = [
        {
          type = "command";
          command = "${config.xdg.configHome}/agents/useless-facts.sh";
        }
      ];
    }
  ];
in
{
  # Shared by every user on the host: the global agent rules and the
  # easter-egg hook travel together with the agent programs.
  xdg.configFile = lib.mkIf agentsEnabled {
    "agents/AGENTS.md".source = ./AGENTS.md;
    "agents/useless-facts.sh" = {
      source = ./useless-facts.sh;
      executable = true;
    };
  };

  # Codex loads global instructions from its home directory.
  home.file.".codex/AGENTS.md" = lib.mkIf (agentsEnabled && toua.codex.enable) {
    source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/agents/AGENTS.md";
  };

  # The hook runs before every submitted prompt. The script draws its odds with
  # shuf and exits silently unless it wins, so the usual case costs one process
  # spawn and contributes nothing to the context. A win prints a
  # `systemMessage`, which the agent renders to the user in the transcript
  # without adding it to the model's context.
  #
  # Managing settings.json at all takes ~/.claude/settings.json out of the
  # user's hands, so the theme the hand-written file used to set is carried
  # over.
  programs.claude-code.settings = lib.mkIf (agentsEnabled && toua.claude-code.enable) {
    theme = "auto";
    hooks.UserPromptSubmit = factHook;
  };

  # Codex reads the same structure from CODEX_HOME/hooks.json. Its hooks are on
  # by default, but it asks the user to trust a hook before running it, so this
  # one has to be accepted once via Codex's `/hooks`.
  programs.codex.hooks = lib.mkIf (agentsEnabled && toua.codex.enable) {
    UserPromptSubmit = factHook;
  };
}
