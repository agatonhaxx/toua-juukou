{ lib, pkgs, ... }:
let
  groups = import ../../modules/groups.nix;
  inherit (import ../../modules/shared/lib.nix { inherit lib; }) mkDefaults;

  # Windows for the wheel filter below, measured from evtest captures of this
  # mouse: chatter lands within a few ms of the tick it belongs to, while a
  # genuine change of direction never came closer than 120ms. 50 splits the
  # two with room to spare. The fastest repeat of the *same* direction was 2ms
  # (one detent reported twice) against 18ms for the next real notch, so 8
  # separates those.
  reverseWindow = 50;
  repeatWindow = 8;
in
{
  imports = [
    ../../user
    ./disko.nix
    ./hardware-configuration.nix
  ];

  # The only `boot.loader` definition: `hardware-configuration.nix` carries the
  # hardware facts and filesystems, this carries boot policy. `/boot` is the ESP
  # declared in ./disko.nix, and the mount point is spelled out because its
  # default has moved between nixpkgs releases.
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

    # Only the services: the desktop profile above already contributes the
    # group's programs, and these are the ones that need the data volume and the
    # group the services share.
    (mkDefaults { inherit (groups.media) services; })
    {
      profiles.desktop.enable = true;

      programs = {
        blueman.enable = true;
        bluetooth.enable = true;
      };

      # Every media service keeps its state on the nvme partition mounted at
      # /data/baymax/qt, next to the download trees they all work in.
      services = {
        immich.dataDir = "/data/baymax/qt/immich";
        jellyfin.dataDir = "/data/baymax/qt/jellyfin";

        # MediaManager is not one of the group's services: only its own data
        # moves here, its libraries stay where they are, see below.
        mediamanager = {
          enable = true;
          dataDir = "/data/baymax/qt/mediamanager";
        };

        navidrome = {
          dataDir = "/data/baymax/qt/navidrome";
          musicDir = "/data/baymax/music";
        };

        # The save paths are the WebUI's own, and point into
        # /data/baymax/qt/download/torrent.
        qbittorrent.dataDir = "/data/baymax/qt/qbittorrent";

        sabnzbd = {
          dataDir = "/data/baymax/qt/sabnzbd";
          incompleteDir = "/data/baymax/qt/download/usenet/incomplete";
          completeDir = "/data/baymax/qt/download/usenet";
        };

        slskd = {
          dataDir = "/data/baymax/qt/slskd";

          # What it offers on the Soulseek network; the unit sees it read-only.
          shares = [ "/data/baymax/music" ];
        };
      };

      primaryUser = "eek";
      users.eek.homeModule = ../../user/eek;
    }
  ];

  # The media services and eek work in the same trees under /data/baymax — the
  # libraries and the download trees — and this group is what gives them access
  # to each other's files: every service module adds its user to it. The trees
  # themselves were regrouped once, since they predate the group:
  #
  #   sudo chgrp -R media /data/baymax/{movies,tv,anime,music} /data/baymax/qt/download
  #   sudo chmod -R g+rwX,g+s /data/baymax/{movies,tv,anime,music} /data/baymax/qt/download
  #
  # `g+rwX` because the libraries were not group-writable, and the setgid bit
  # because that is what keeps the group on everything written below them. The
  # services' own state directories are deliberately not in this group.
  users.groups.media = { };
  users.users.eek.extraGroups = [ "media" ];

  # One instance for the media services that need a database — MediaManager and
  # immich — with its cluster on the data volume next to the state it belongs
  # to. The module points the unit at `dataDir` and runs initdb there, but
  # creates nothing itself, so the directory is created here. A cluster left
  # behind in /var/lib/postgresql is not migrated.
  services.postgresql.dataDir = "/data/baymax/qt/postgres";

  systemd.tmpfiles.settings."10-postgresql-media"."/data/baymax/qt/postgres".d = {
    user = "postgres";
    group = "postgres";
    mode = "0700";
  };

  # MediaManager's scan roots are the finished-download tree, not the libraries:
  # it lists the direct children of these two as import candidates and excludes
  # only a path that is itself a configured library. They sit on the xfs volume
  # with the libraries, which is what makes an import a hardlink and not a copy.
  #
  # The libraries are where an import is organised to, and neither `Default` nor
  # an unset library is one of them — both mean `movie_directory` — so every
  # movie and show needs its library picked in the UI. `image_directory` has no
  # existing home and stays under `dataDir`.
  #
  # The download clients save into the same tree: unfinished work on the nvme,
  # finished work here, so the spindles take one sequential write per item.
  services.media-manager.settings.misc = {
    movie_directory = "/data/baymax/downloads/movies";
    tv_directory = "/data/baymax/downloads/tv";
    torrent_directory = "/data/baymax/downloads";

    movie_libraries = [ { name = "Movies"; path = "/data/baymax/movies"; } ];
    tv_libraries = [
      { name = "TV"; path = "/data/baymax/tv"; }
      { name = "Anime"; path = "/data/baymax/anime"; }
    ];
  };

  # MediaManager's rule creates the three directories it is pointed at; these
  # are the finished-download categories it is not, made here so the clients
  # write into a setgid directory of the media group rather than one of their
  # own. `20-` so it runs after that rule has made their parent.
  systemd.tmpfiles.settings."20-media-downloads" = lib.genAttrs [
    "/data/baymax/downloads/anime"
    "/data/baymax/downloads/music"
  ] (_: {
    d = {
      user = "media-manager";
      group = "media";
      mode = "2775";
    };
  });

  # This host's wheel reports one detent more than once — a worn encoder, not a
  # driver problem. `mouse-wheel-debounce` (pkgs/) drops those reports by their
  # kernel timestamps, and interception-tools is what puts it *below* libinput,
  # so the events it discards are events no compositor ever sees: `intercept`
  # grabs the device, the filter rewrites the stream, and `uinput` replays it as
  # a virtual device in its place.
  #
  # It stays in this file because it is one failing wheel, not a fleet policy,
  # and because a grabbed device is one nothing else can read. The udevmon job
  # is scoped to that wheel by name, and to the relative-event codes only a
  # wheel reports, so nothing else is ever grabbed — the mouse also presents
  # two keyboard interfaces under the same name.
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
