{
  config,
  lib,
  ...
}:
{
  programs.zk = lib.mkIf config.programs.zk.enable {
    # Only matters for editor plugins launched outside a notebook directory;
    # deriving it from `notebook.dir` keeps the path in one place.
    exportNotebookDir = true;

    settings = {
      notebook.dir = "${config.home.homeDirectory}/dev/eek/hive-mind";

      note = {
        dir = "notes";
        # The default title used for new note, if no `--title` flag is provided.
        # Template used to generate a note's filename, without extension.
        filename = "{{title}}-{{id}}";
        language = "en";
        extension = "md";
        template = "default.md";
        id-charset = "hexadecimal";
        id-length = 8;
        id-case = "lower";
      };

      format.markdown = {
        hashtags = true;
        multiword-tags = false;
        link-format = "wiki";
        colon-tags = true;
      };

      group = {
        daily = {
          paths = [ "journal/daily" ];
          note = {
            extension = "md";
            filename = "{{format-date now}}-daily";
            template = "daily.md";
          };
        };
        knowhow = {
          paths = [ "know-how" ];
          note = {
            filename = "{{title}}";
            template = "know-how.md";
            extension = "md";
          };
        };
        recipe = {
          paths = [ "recipe" ];
          note = {
            filename = "{{title}}-recipe";
            template = "recipe.md";
            extension = "md";
          };
        };
      };

      tool = {
        editor = "nvim";
        fzf-preview = "bat --color=always {-1}";
      };

      alias = {
        recent = "zk list --sort created- --created-after 'last two weeks' $@";
        tags = "zk list --format '{{tags}}' $@ | tr ',' '\n' | sort -u";
        daily = "zk new --title $argv 'journal/daily'";
        knowhow = "zk new --title $argv 'knowhow'";
        recipe = "zk new --title $argv 'recipe'";
      };

      lsp = {
        diagnostics = {
          # Report titles of wiki-links as hints.
          wiki-title = "hint";
          # Warn for dead links between notes.
          dead-link = "error";
          # Warn when notes link here without backlinks.
          missing-backlink = {
            level = "warning";
            position = "bottom";
          };
        };
      };
    };
  };
}
