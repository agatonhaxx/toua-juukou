{
  lib,
  config,
  ...
}:

{
  programs.starship = lib.mkIf config.programs.starship.enable {
    settings = {
      add_newline = true;
      continuation_prompt = "[](yellow) ";
      format = builtins.concatStringsSep "" [
        "┌ "

        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_commit"
        "$git_state"
        "$git_metrics"
        "$git_status"
        "$package"
        "$nodejs"
        "$python"
        "$rust"
        "$sudo"
        "$fill"
        "$kubernetes"

        "$line_break"
        "└ "

        "$shell"
        "$character"
      ];
      command_timeout = 1000;

      fill.symbol = " ";

      character = {
        success_symbol = "[\\$](green)";
        error_symbol = "[\\$](red)";
      };

      username = {
        format = "\\[[$user](pink)[@](lavender)";
      };
      hostname = {
        style = "mauve";
        format = "[$hostname]($style)\\] ";
      };

      directory = {
        truncation_length = 5;
        truncate_to_repo = false;
        style = "blue";
        read_only = " ";
        read_only_style = "red";
      };

      shell = {
        disabled = false;
        style = "sky";
        format = "[$indicator]($style)";
        fish_indicator = ""; # default shell
        nu_indicator = "\\[[nu](green)\\] ";
        bash_indicator = "\\[[bash](red)\\] ";
        zsh_indicator = "\\[[zsh](yellow)\\] ";
      };

      git_branch = {
        symbol = "";
        style = "mauve";
        format = "[on $symbol $branch]($style) ";
      };

      git_status = {
        conflicted = "";
        ahead = ">";
        behind = "<";
        diverged = "#";
        untracked = "?";
        stashed = "≡";
        modified = "!";
        staged = "+";
        renamed = "%";
        deleted = "X";
      };

      package = {
        symbol = "";
        style = "peach";
        format = "[is $symbol $version]($style) ";
        version_format = "v\${raw}";
        display_private = true;
      };

      nodejs = {
        symbol = "";
        style = "green";
        not_capable_style = "red";
        format = "[via $symbol $version]($style) ";
        version_format = "v\${raw}";
      };

      python = {
        symbol = "󱔎";
        style = "yellow";
        format = "[via $symbol $version]($style) ";
        version_format = "v\${raw}";
      };

      rust = {
        symbol = "";
        style = "red";
        format = "[via $symbol $version]($style) ";
        version_format = "v\${raw}";
      };

      # Kubernetes context, right-aligned on the prompt's first line: it is
      # placed after `$fill` in `format`, which is what pushes it to the edge.
      #
      # This module ships disabled. It keys off $KUBECONFIG or ~/.kube/config
      # rather than the kubectl binary, so it appears whenever a current
      # context exists and stays silent otherwise -- no explicit guard needed.
      kubernetes = {
        disabled = false;
        symbol = "☸ ";
        style = "yellow"; # catppuccin_mocha.yellow, unused elsewhere here
        format = "[$symbol$context( \\($namespace\\))]($style) ";
      };
    };
  };
}
