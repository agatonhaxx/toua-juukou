{
  config,
  lib,
  ...
}:
let
  # Both the rules file and the hook are only meaningful where the agent
  # programs themselves are installed.
  agentsEnabled = config.programs.codex.enable || config.programs.claude-code.enable;

  # Both agents expose the same prompt-submission event and `systemMessage`
  # output shape, so one handler entry serves them all.
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
  home.file.".codex/AGENTS.md" = lib.mkIf config.programs.codex.enable {
    source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/agents/AGENTS.md";
  };

  # Runs before every prompt and usually exits silently; a win prints a
  # `systemMessage`, which reaches the user, not the model's context.

  # Managing settings.json takes the hand-written ~/.claude/settings.json out of
  # the user's hands, so the theme it used to set is carried over.
  programs.claude-code.settings = lib.mkIf config.programs.claude-code.enable {
    theme = "auto";
    hooks.UserPromptSubmit = factHook;
  };

  # Codex reads the same structure from CODEX_HOME/hooks.json, but asks the user
  # to trust a hook once via `/hooks` before running it.
  programs.codex.hooks = lib.mkIf config.programs.codex.enable {
    UserPromptSubmit = factHook;
  };
}
