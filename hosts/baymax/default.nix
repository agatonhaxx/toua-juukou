{ lib, pkgs, ... }:
let
  groups = import ../../modules/groups.nix;
  inherit (import ../../modules/shared/lib.nix { inherit lib; }) mkDefaults;

  # Wheel-debounce windows, from evtest captures of this mouse: chatter lands
  # within a few ms of its tick, a real reversal never under 120 ms.
  reverseWindow = 80;
  repeatWindow = 10;
in
{
  imports = [
    ../../user
    ./disko.nix
    ./hardware-configuration.nix
  ];

  # `hardware-configuration.nix` carries the hardware and filesystems, this
  # carries boot policy; `/boot` is the ESP declared in ./disko.nix.
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    systemd-boot.graceful = true;
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  networking = {
    hostName = "baymax";
    networkmanager.enable = true;

    # Flow syncs between machines over this port.
    firewall.allowedTCPPorts = [ 43251 ];
  };

  systemd.services.NetworkManager-wait-online.enable = false;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICPdH1DIHY40eBUaRiMsneGlZsLJ+lQFIQwCAe4KTxCU"
  ];
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../../keys/authorized_keys ];

  services.avahi.ipv6 = false;

  toua = lib.mkMerge [
    (mkDefaults groups.dev)
    (mkDefaults groups.agents)

    # Only its services: the desktop profile above already brings the group's
    # programs.
    (mkDefaults { inherit (groups.media) services; })
    {
      profiles.desktop.enable = true;

      programs = {
        blueman.enable = true;
        bluetooth.enable = true;
      };

      # Every media service keeps its state on the nvme at /data/baymax/qt.
      services = {
        pics.dataDir = "/data/baymax/qt/immich";
        jellyfin.dataDir = "/data/baymax/qt/jellyfin";

        music = {
          dataDir = "/data/baymax/qt/navidrome";
          musicDir = "/data/baymax/music";
        };

        prowlarr.dataDir = "/data/baymax/qt/prowlarr";

        # The WebUI owns its paths: unfinished work on the nvme, finished work
        # in the download tree below.
        qbittorrent.dataDir = "/data/baymax/qt/qbittorrent";

        # The arrs: their own state, next to the libraries they import from.
        # Root folders, download clients and quality profiles are the WebUI's.
        radarr.dataDir = "/data/baymax/qt/radarr";
        sonarr.dataDir = "/data/baymax/qt/sonarr";

        # Assembling stays on the nvme, finishing happens in the tree the arrs
        # import from; the per-category folder is set in the WebUI.
        sabnzbd = {
          dataDir = "/data/baymax/qt/sabnzbd";
          incompleteDir = "/data/baymax/qt/download/usenet/incomplete";
          completeDir = "/data/baymax/downloads";
        };

        slskd = {
          dataDir = "/data/baymax/qt/slskd";

          # What it offers on the Soulseek network; the unit sees it read-only.
          shares = [ "/data/baymax/music" ];
        };
      };
    }
  ];

  # Shares the libraries and download trees between the media services and eek;
  # the trees predate the group and were regrouped with `chgrp -R media` + `g+rwX,g+s`.
  users.groups.media = { };
  users.users.eek.extraGroups = [ "media" ];

  # immich's module enables the cluster and owns the database but creates
  # nothing, so the directory below is made here; the cluster lives on /data.
  services.postgresql.dataDir = "/data/baymax/qt/postgres";

  systemd.tmpfiles.settings."10-postgresql-media"."/data/baymax/qt/postgres".d = {
    user = "postgres";
    group = "postgres";
    mode = "0700";
  };

  # This host's wheel repeats detents — a worn encoder — so the filter runs below
  # libinput via interception-tools; it stays per-host, not as a fleet policy.
  services.interception-tools = {
    enable = true;

    # Contributes the filter to udevmon's PATH, which is where the job finds it
    # by name.
    plugins = [ pkgs.mouse-wheel-debounce ];

    udevmonConfig = ''
      - JOB: "intercept -g $DEVNODE | mouse-wheel-debounce --reverse-window ${toString reverseWindow} --repeat-window ${toString repeatWindow} | uinput -d $DEVNODE"
        DEVICE:
          NAME: "Mionix Co. Naos 3200 Mouse"
          EVENTS:
            EV_REL: [REL_WHEEL, REL_WHEEL_HI_RES]
    '';
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    generateHostKeys = true;
    settings.PermitRootLogin = "prohibit-password";
  };
}
