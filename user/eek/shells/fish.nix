{
  pkgs,
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.programs.fish.enable {
    programs.fish = {
      shellAbbrs = {
        "cx" = "chmod +x";

        "gp" = "git push";
        "gc" = "git commit -m";
        "gs" = "git status";
        "ga" = "git add";
      };

      shellAliases = {
        "l" = "eza";
      };

      plugins = [
        {
          name = "autopair";
          src = pkgs.fetchFromGitHub {
            owner = "jorgebucaran";
            repo = "autopair.fish";
            rev = "244bb1ebf74bf944a1ba1338fc1026075003c5e3";
            sha256 = "sha256-s1o188TlwpUQEN3X5MxUlD/2CFCpEkWu83U9O+wg3VU=";
          };
        }
      ];

      shellInit = ''
        # https://fishshell.com/docs/current/cmds/fish_greeting.html
        set fish_greeting
      '';

      functions = {
        # `zk new` reads its argument as a directory; for words that are not one,
        # build a title instead — a real directory keeps the native behaviour.
        zk = ''
          if test (count $argv) -ge 2; and test "$argv[1]" = new
            set -l target "$argv[2]"
            if not string match -q -- '-*' "$target"; and not test -d "$target"; and not test -d "$ZK_NOTEBOOK_DIR/$target"
              command zk new --title (string join " " -- $argv[2..-1])
              return $status
            end
          end

          command zk $argv
        '';

        # Recursively create and enter a directory path.
        take = ''
          set dir $argv[1]
          if test -z "$dir"
              return 1
          end

          mkdir -p "$dir"
          cd "$dir"
        '';

        mk = ''
          set dir (dirname $argv[1])
          set file (basename $argv[1])
          mkdir -p $dir
          touch $dir/$file
        '';

        # Check if a command is present in PATH.
        have = ''
          command -v $argv > /dev/null
        '';

        # Convert all PNG files in the CWD to WebP.
        png_to_webp = ''
          for file in *.png
            set output (basename $file .png).webp
            cwebp -lossless $file -o $output
          end
        '';

        # Like https://github.com/nix-community/comma, but who needs a whole CLI tool for it.
        "," = ''
          nix run "nixpkgs#$argv[1]" -- $argv[2..-1]
        '';

        # Needs an unlocked `bw` session; REPLACE-ME is the item name.
        with_gh_token = ''
          set -lx GITHUB_TOKEN (bw get password REPLACE-ME)
          command $argv
        '';

        gh = ''
          set user $(git config user.name)
          if command gh auth status --json hosts --jq '.hosts["github.com"].[].login' | grep -Fqx "$user"
            command gh auth switch -u "$user" >/dev/null 2>&1
          else
            echo "gh: matching gh user for git user '$user' not found"
          end

          command gh $argv
        '';
      };
    };

    xdg.configFile =
      let
        symlink =
          fileName:
          {
            recursive ? false,
          }:
          {
            source = config.lib.file.mkOutOfStoreSymlink "${fileName}";
            inherit recursive;
          };
      in
      {
        "fish/completions" = symlink "${./fish/completions}" { recursive = true; };

        # File by file: `programs.fish.functions` writes its own files into this
        # same directory, so a directory symlink would collide with them.
        "fish/functions/mkpasswd2.fish" = symlink "${./fish/functions/mkpasswd2.fish}" { };
      };
  };
}
