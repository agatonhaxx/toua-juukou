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

        prowlarr.dataDir = "/data/baymax/qt/prowlarr";

        # The WebUI owns its paths: unfinished work in
        # /data/baymax/qt/download/torrent on the nvme, finished work in the
        # download tree below.
        qbittorrent.dataDir = "/data/baymax/qt/qbittorrent";

        # Assembling stays on the nvme, but finishing means the tree
        # MediaManager scans. There is one scan root per type and the folder is
        # set per category in the WebUI, so `anime` finishes in the TV tree with
        # `tv` rather than in one of its own, and both land in the TV library.
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

      primaryUser = "eek";
      users.eek.homeModule = ../../user/eek;
    }
  ];

  # The media services and eek work in the same trees under /data/baymax — the
  # libraries and the download trees — and this group is what gives them access
  # to each other's files: every service module adds its user to it. The trees
  # themselves were regrouped once, since they predate the group:
  #
  #   sudo chgrp -R media /data/baymax/{movies,tv,music} /data/baymax/qt/download
  #   sudo chmod -R g+rwX,g+s /data/baymax/{movies,tv,music} /data/baymax/qt/download
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
  #
  # `torrent_directory` is where MediaManager would add torrents of its own, and
  # no client is pointed at it, so it is a subdirectory of the tree rather than
  # the tree's root: the tmpfiles rule below takes ownership of every path it is
  # given, and the root is SABnzbd's complete directory.
  services.media-manager.settings.misc = {
    movie_directory = "/data/baymax/downloads/movies";
    tv_directory = "/data/baymax/downloads/tv";
    torrent_directory = "/data/baymax/downloads/torrents";

    movie_libraries = [
      {
        name = "Movies";
        path = "/data/baymax/movies";
      }
    ];
    tv_libraries = [
      {
        name = "TV";
        path = "/data/baymax/tv";
      }
    ];
  };

  # The module ships every client switched off, with the credentials left out
  # on purpose, so what is turned on here is what this host actually runs:
  # Prowlarr for searches and qBittorrent for the torrents. Both credentials
  # arrive from the sops env file rather than this file, as
  # `MEDIAMANAGER_INDEXERS__PROWLARR__API_KEY` and
  # `MEDIAMANAGER_TORRENTS__QBITTORRENT__PASSWORD` — the module documents the
  # scheme.
  #
  # Prowlarr is only an API to MediaManager, which enumerates and queries the
  # indexers itself, so Prowlarr needs no download client and no App entry:
  # those serve Prowlarr's own manual grab and the Sonarr/Radarr sync, and
  # neither exists here. SABnzbd is left off until there are usenet indexers to
  # feed it — MediaManager picks a client per result, and a usenet result with
  # no usenet client raises rather than falling back.
  #
  # MediaManager creates this category in qBittorrent itself and adds every
  # torrent into it with the release title as the path below, so the save path
  # has to be `torrent_directory` as qBittorrent sees it — same host, so the
  # same path. What it grabs finishes there and the import job hardlinks it into
  # a library; the per-type categories in the WebUI are for manual grabs, which
  # arrive through the scan roots above instead.
  services.media-manager.settings = {
    torrents.qbittorrent = {
      enabled = true;
      host = "http://localhost";
      port = 8080;
      category_save_path = "/data/baymax/downloads/torrents";
    };

    indexers.prowlarr = {
      enabled = true;
      url = "http://localhost:9696";
    };
  };

  # Scoring rules rank what a search turns up. A rule runs only when a rule set
  # names it, and a set runs for the media it is scoped to: `ALL_TV` and
  # `ALL_MOVIES` are every show and film whatever library it is filed under, so
  # the two sets below stay out of each other's way. Keywords are substrings of
  # the result title, folded to case, and `negate` would make a rule fire on
  # their absence instead. A result that ends at zero or below is dropped, which
  # is how the negative rules remove rather than merely rank.
  #
  # The size MediaManager gets from the indexer is never scored — nothing in the
  # config reads it — so "not huge" has to be said in the tokens that imply it,
  # which is what the movie rules do.
  #
  # TV ranks the codec and the groups: the groups are worth more than the codec,
  # so one of them wins against an h265 release from anywhere else, and the
  # anime groups are here because anime imports into this same library now.
  services.media-manager.settings.indexers = {
    title_scoring_rules = [
      {
        name = "prefer_h265";
        keywords = [
          "h265"
          "hevc"
          "x265"
        ];
        score_modifier = 100;
        negate = false;
      }
      {
        name = "prefer_tv_groups";
        keywords = [
          # keep-sorted start
          "ToonsHub"
          "BlackRabbit"
          "Trix"
          "Ironclad"
          "SubsPlease"
          "Erai-raws"
          "Judas"
          "ASW"
          "Moozzi2"
          "Anime Time"
          # keep-sorted end
        ];
        score_modifier = 500;
        negate = false;
      }

      # Movies: 1080p is 100, BluRay another 100 and x265 50 more, so a 1080p
      # BluRay encode tops out at 250, or 750 from one of the groups below. The
      # two negatives outweigh all of that together, so no 4K or remuxed release
      # survives the sort. The codec rule repeats TV's keywords on purpose: a
      # separate name is what lets the two media types weigh the codec apart.
      {
        name = "prefer_1080p";
        keywords = [
          "1080p"
        ];
        score_modifier = 100;
        negate = false;
      }
      {
        name = "prefer_bluray";
        keywords = [
          "bluray"
          "bdrip"
        ];
        score_modifier = 100;
        negate = false;
      }
      {
        name = "prefer_x265";
        keywords = [
          "x265"
          "h265"
          "hevc"
        ];
        score_modifier = 50;
        negate = false;
      }
      {
        name = "no_4k";
        keywords = [
          "2160p"
          "4k"
          "uhd"
        ];
        score_modifier = -1000;
        negate = false;
      }
      {
        name = "no_remux";
        keywords = [
          "remux"
        ];
        score_modifier = -1000;
        negate = false;
      }

      # The groups worth waiting for: 1080p BluRay encodes at a sensible size,
      # x264 and x265 both, which is what the rules above are already ranking.
      # Remux-only groups (`Framestor`, `WiLDCAT`, `KRaLiMaRKo`) are absent
      # because `no_remux` drops their releases whatever they score, and the
      # groups that only do tiny encodes (`YIFY`, `r00t`, `GALAXY`) sit below
      # the size this set aims at. Matching is by substring, so a tag that hides
      # inside an ordinary word is out as well — `EVO` in "Evolution", `HONE` in
      # "Phone", `iFT` in "Gift".
      {
        name = "prefer_movie_groups";
        keywords = [
          "SPARKS"
          "GECKOS"
          "AMIABLE"
          "Tigole"
          "PSA"
          "QxR"
          "Vyndros"
          "TOMMY"
          "EDITH"
          "FRDS"
          "WiKi"
          "RARBG"
        ];
        score_modifier = 500;
        negate = false;
      }
    ];

    scoring_rule_sets = [
      {
        name = "tv";
        libraries = [ "ALL_TV" ];
        rule_names = [
          "prefer_h265"
          "prefer_tv_groups"
        ];
      }
      {
        name = "movies";
        libraries = [ "ALL_MOVIES" ];
        rule_names = [
          "prefer_1080p"
          "prefer_bluray"
          "prefer_x265"
          "no_4k"
          "no_remux"
          "prefer_movie_groups"
        ];
      }
    ];
  };

  # MediaManager's rule creates the directories it is pointed at; this is the
  # one finished-download category it has no scan root for — music never reaches
  # it — made here so the clients write into a setgid directory of the media
  # group rather than one of their own. `20-` so it runs after the rules that
  # make the tree above it.
  systemd.tmpfiles.settings."20-media-downloads"."/data/baymax/downloads/music".d = {
    user = "media-manager";
    group = "media";
    mode = "2775";
  };

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
