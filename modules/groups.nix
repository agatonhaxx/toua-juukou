{
  cli.programs = {
    # keep-sorted start
    atuin.enable = true;
    bash.enable = true;
    bat.enable = true;
    coreutils.enable = true;
    curl.enable = true;
    direnv.enable = true;
    dust.enable = true;
    eza.enable = true;
    fd.enable = true;
    fish.enable = true;
    git.enable = true;
    gnupg.enable = true;
    navi.enable = true;
    neovim.enable = true;
    nix-diff.enable = true;
    ouch.enable = true;
    ripgrep.enable = true;
    starship.enable = true;
    yazi.enable = true;
    yubikey-manager.enable = true;
    zk.enable = true;
    zoxide.enable = true;
    zsh.enable = true;
    # keep-sorted end
  };

  dev.programs = {
    # keep-sorted start
    gcloud.enable = true;
    jless.enable = true;
    jnv.enable = true;
    jq.enable = true;
    just.enable = true;
    yq.enable = true;
    # keep-sorted end
  };

  agents.programs = {
    claude-code.enable = true;
    codex.enable = true;
  };

  k8s.programs = {
    helm.enable = true;
    k9s.enable = true;
    kubectl.enable = true;
  };

  gui = {
    graphical.enable = true;
    fonts.enable = true;
    programs = {
      # Left off: whether a machine has a radio is a hardware fact, so a host
      # opts in rather than the group.
      # keep-sorted start
      blueman.enable = false;
      bluetooth.enable = false;
      chromium.enable = true;
      discord.enable = true;
      firefox.enable = true;
      vscode.enable = true;
      wezterm.enable = true;
      # keep-sorted end
    };
  };

  # The games themselves and the tools that wrap them. What the group needs from
  # the machine rather than from a user's session — the larger `vm.max_map_count`,
  # AppImage binfmt and the sched-ext scheduler — is not a program of its own, so
  # it hangs off `steam` in modules/nixos/gaming.nix.
  gaming.programs = {
    # keep-sorted start
    gamemode.enable = true;
    gamescope.enable = true;
    mangohud.enable = true;
    steam.enable = true;
    # keep-sorted end
  };

  media = {
    programs = {
      # keep-sorted start
      ffmpeg.enable = true;
      flow.enable = true;
      mpv.enable = true;
      qbittorrent.enable = true;
      # keep-sorted end
    };

    # The services share a data volume and a group of their own, which not every
    # machine has, so no other group pulls them in: a host opts into them.
    services = {
      # keep-sorted start
      jellyfin.enable = true;
      music.enable = true;
      pics.enable = true;
      prowlarr.enable = true;
      qbittorrent.enable = true;
      radarr.enable = true;
      sabnzbd.enable = true;
      slskd.enable = true;
      sonarr.enable = true;
      # keep-sorted end
    };
  };

  mac.programs = {
    bitwarden.enable = true;
    raycast.enable = true;
    sf-symbols.enable = true;
  };

  network.services = {
    tailscale = {
      enable = true;

      # Wall-e runs the control server, so that one address is what the whole
      # fleet joins instead of Tailscale's own. Each host authenticates with its
      # own preauth key in secrets/services/tailscale.yaml.
      loginServer = "https://headscale.huxe.eu";
    };
  };

  server.services = {
    # keep-sorted start
    acme.enable = true;
    atuin.enable = true;
    borgbackup.enable = true;
    kanidm.enable = true;
    nginx.enable = true;
    vaultwarden.enable = true;
    # keep-sorted end
  };
}
