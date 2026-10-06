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
        "ll" = "l -la";

        "nixpkgs-using" = "with_gh_token nixpkgs-using";
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
        # `zk new` normally treats its positional argument as a directory. For a
        # nonexistent path, make the convenient `zk new my title` form create a
        # titled note while preserving the native behavior for real directories.
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

        # Fetches the token from Bitwarden and runs the command with it in the
        # environment. Needs an unlocked `bw` session; the item name is a
        # placeholder.
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

        # `programs.fish.functions` writes one file per function into this same
        # directory, so it can only be extended file by file — a directory symlink
        # here would collide with the functions declared above.
        "fish/functions/mkpasswd2.fish" = symlink "${./fish/functions/mkpasswd2.fish}" { };
      };
  };
}
