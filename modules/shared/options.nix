{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types;

  cfg = config.toua;

  agentProgramNames = [
    # keep-sorted start
    "claude-code"
    "codex"
    # keep-sorted end
  ];

  mediaProgramNames = [
    # keep-sorted start
    "ffmpeg"
    "flow"
    "mpv"
    "qbittorrent"
    # keep-sorted end
  ];

  k8sProgramNames = [
    # keep-sorted start
    "helm"
    "k9s"
    "kubectl"
    # keep-sorted end
  ];

  devProgramNames = [
    # keep-sorted start
    "gcloud"
    "jless"
    "jnv"
    "jq"
    "just"
    "yq"
    # keep-sorted end
  ];

  cliProgramNames = [
    # keep-sorted start
    "atuin"
    "bat"
    "coreutils"
    "curl"
    "direnv"
    "dust"
    "eza"
    "fd"
    "git"
    "gnupg"
    "navi"
    "neovim"
    "nix-diff"
    "ouch"
    "ripgrep"
    "starship"
    "yazi"
    "yubikey-manager"
    "zk"
    "zoxide"
    # keep-sorted end
  ];

  guiProgramNames = [
    # keep-sorted start
    "chromium"
    "firefox"
    "kiwidesk"
    "niri"
    "vscode"
    "wezterm"
    # keep-sorted end
  ];

  mkProgramOptions =
    group: names:
    lib.genAttrs names (name: {
      enable = mkEnableOption name // {
        default = cfg.programs.${group}.enable;
      };
    });

  agentProgramOptions = mkProgramOptions "agents" agentProgramNames;
  mediaProgramOptions = mkProgramOptions "media" mediaProgramNames;
  cliProgramOptions = mkProgramOptions "defaults" cliProgramNames;
  devProgramOptions = mkProgramOptions "dev" devProgramNames;
  k8sProgramOptions = mkProgramOptions "k8s" k8sProgramNames;

  guiProgramOptions = lib.genAttrs guiProgramNames (name: {
    enable = mkEnableOption name // {
      default = if name == "kiwidesk" || name == "niri" then false else cfg.programs.gui.enable;
    };
  });

  programGroups = {
    agents.enable = mkEnableOption "agent tools";
    defaults.enable = mkEnableOption "the default CLI programs";
    dev.enable = mkEnableOption "development tools";
    gui.enable = mkEnableOption "GUI programs";
    k8s.enable = mkEnableOption "Kubernetes tools";
    media.enable = mkEnableOption "media applications" // {
      default = cfg.programs.gui.enable;
    };
    mediaAssociations.enable = mkEnableOption "media file associations" // {
      default = cfg.programs.gui.enable;
    };
  };

  serviceOptions = {
    defaults.enable = mkEnableOption "the default services";
  };

in
{
  options.toua = {
    primaryUser = mkOption {
      type = types.str;
      default = "eek";
      description = ''
        The primary user for integrations that require one user, such as
        Homebrew, WSL, and the Darwin system configuration.
      '';
    };

    users = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkEnableOption "Manage this user";

            homeModule = mkOption {
              type = types.path;
              default = ../../user/home.nix;
              description = "Home Manager module for this user.";
            };
          };
        }
      );
      default = { };
      description = "Users managed by this host, keyed by username.";
    };

    manageUser = mkEnableOption "Declare the user account in the system config" // {
      default = true;
    };

    timeZone = mkOption {
      type = types.str;
      default = "Europe/Stockholm";
      description = ''
        System time zone, applied on every platform. Declared here rather
        than in a platform module because both NixOS and nix-darwin define
        `time.timeZone` and can act on it — on Darwin it is applied with
        `systemsetup -settimezone` from an activation script.
      '';
    };

    programs =
      programGroups
      // agentProgramOptions
      // mediaProgramOptions
      // cliProgramOptions
      // devProgramOptions
      // k8sProgramOptions
      // guiProgramOptions;

    services = serviceOptions;

    shells = {
      enable = mkEnableOption "Enable (other) shell programs" // {
        default = false;
      };

      bash.enable = mkEnableOption "Enable Bash" // {
        default = cfg.shells.enable;
      };

      zsh.enable = mkEnableOption "Enable Zsh" // {
        default = cfg.shells.enable;
      };
    };

    # Gated on `programs.gui.enable` because a headless machine has no use for
    # a desktop font stack.
    fonts.enable = mkEnableOption "Enable desktop fonts" // {
      default = cfg.programs.gui.enable;
    };
  };
}
