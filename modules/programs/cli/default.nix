{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib; })
    importDir
    mkEnabledPackages
    mkProgramToggles
    ;

  cfg = config.toua.programs;
in
{
  # One module per tool that needs more than a package; `importDir` skips this
  # file, so they are imported here.
  imports = importDir { dir = ./.; };

  # A toggle and a package per CLI tool, both driven by the host's selection.
  programs =
    mkProgramToggles cfg [
      # keep-sorted start
      "atuin"
      "bat"
      "claude-code"
      "codex"
      "direnv"
      "eza"
      "fd"
      "git"
      "jq"
      "k9s"
      "navi"
      "ripgrep"
      "starship"
      "yazi"
      "zk"
      "zoxide"
      # keep-sorted end
    ]
    // {
      # The host option uses the tool name; Home Manager calls its module gpg.
      gpg.enable = lib.mkDefault cfg.gnupg.enable;
    };

  home.packages = mkEnabledPackages cfg {
    # keep-sorted start
    coreutils = pkgs.uutils-coreutils-noprefix;
    curl = pkgs.curl;
    dust = pkgs.dust;
    ffmpeg = pkgs.ffmpeg;
    flow = pkgs.flow;
    gcloud = pkgs.google-cloud-sdk;
    helm = pkgs.kubernetes-helm;
    jless = pkgs.jless;
    jnv = pkgs.jnv;
    just = pkgs.just;
    kubectl = pkgs.kubectl;
    nix-diff = pkgs.nix-diff;
    ouch = pkgs.ouch;
    yq = pkgs.yq-go;
    yubikey-manager = pkgs.yubikey-manager;
    # keep-sorted end
  };
}
