{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "";
      };
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    easy-hosts.url = "github:isabelroses/easy-hosts";

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin-custom-icons.url = "github:ryanccn/nix-darwin-custom-icons";
    darwin-login-items.url = "github:uncenter/nix-darwin-login-items";

    # Manages the Homebrew installation itself. Its only input is brew-src, so it
    # must NOT take inputs.nixpkgs.follows.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvim-eek.url = "github:agatonhaxx/nvim-eek";
    nvim-eek.inputs.nixpkgs.follows = "nixpkgs";

    # The navi cheatsheets. A bare data repo — no flake.nix, just `cheat/` — so
    # it is read as a plain source tree rather than as a flake.
    navi-eek = {
      url = "github:agatonhaxx/navi-eek";
      flake = false;
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        # keep-sorted start
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
        # keep-sorted end
      ];

      imports = [
        # keep-sorted start prefix_order=inputs.,./
        inputs.git-hooks.flakeModule
        inputs.treefmt-nix.flakeModule
        ./hosts
        # keep-sorted end
      ];

      perSystem =
        { config, pkgs, ... }:
        let
          removeDsStore = pkgs.writeShellScript "remove-ds-store" ''
            cd "$(git rev-parse --show-toplevel)"
            find . -path './.git' -prune -o -type f -name '.DS_Store' -delete

            while IFS= read -r -d "" path; do
              if [[ "$path" == ".DS_Store" || "$path" == */.DS_Store ]]; then
                git add -u -- "$path"
              fi
            done < <(git ls-files --cached -z)
          '';
        in
        {
          # Exposed as the flake `formatter`, so `nix fmt` and the `treefmt` from
          # the devshell below run the exact same formatters over the same tree.
          treefmt = {
            programs.keep-sorted.enable = true;
            programs.nixfmt.enable = true;

            # Covers `user/eek/scripts/*.sh` and the root `.envrc`. Unlike nixfmt
            # this is a linter, not a rewriter: a finding fails the treefmt run
            # (and so the pre-commit hook) rather than being fixed in place.
            programs.shellcheck.enable = true;

            # Matches every file, so this is the one formatter here that reads
            # prose. Words it does not know belong in `typos.toml` at the root
            # rather than being renamed to something the dictionary accepts.
            programs.typos.enable = true;

            # `checks.pre-commit` below runs treefmt over the same tree, so this
            # separate check would be a second copy of the same work.
            flakeCheck = false;
          };

          pre-commit = {
            check.enable = true;

            settings.hooks = {
              treefmt.enable = true;

              remove-ds-store = {
                enable = true;
                name = "remove .DS_Store files";
                entry = "${removeDsStore}";
                language = "system";
                pass_filenames = false;
                always_run = true;
              };
            };
          };

          devShells.default = pkgs.mkShell {
            # Installs the git hook on entry, and puts `pre-commit` on PATH so it
            # can be run over the tree by hand. The hook itself formats only the
            # files going into the commit.
            shellHook = config.pre-commit.shellHook;

            packages = [
              config.treefmt.build.wrapper
              pkgs.just

              # `secrets/README.md` has you run these by hand when bootstrapping
              # a host or rotating keys.
              # keep-sorted start
              pkgs.age
              pkgs.sops
              pkgs.ssh-to-age
              # keep-sorted end

              # Provisioning a bare machine.
              # keep-sorted start
              pkgs.disko
              pkgs.nixos-anywhere
              # keep-sorted end
            ];
          };
        };
    };
}
