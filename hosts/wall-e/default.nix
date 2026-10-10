{
  lib,
  ...
}:
let
  domain = "huxe.eu";

  # The media services wall-e fronts for tailnet clients only; nginx refuses
  # every other source. The list is the services' own names, and each one's
  # port comes from its module. They are named under the MagicDNS base domain,
  # which is the only thing that resolves them; headscale publishes the record.
  tailnetServices = [
    # keep-sorted start
    "music"
    "prowlarr"
    "qbittorrent"
    "radarr"
    "sabnzbd"
    "slskd"
    "sonarr"
    # keep-sorted end
  ];
in
{
  imports = [
    ../../user

    ./disko.nix
  ];

  toua = {
    # wall-e is a headless service host. Keep the shared terminal setup, but do
    # not pull graphical applications or media players into its closure.
    profiles.headless.enable = true;

    inherit domain;
    email = "glenn@huxe.eu";

    # Endpoints for the services on baymax, which wall-e reaches over Tailscale
    # by its MagicDNS name. `enable` stays false: the services run on baymax and
    # this host only fronts them. Only a name someone off the tailnet has to
    # resolve needs a Cloudflare A/AAAA record pointing here, and acme's DNS-01
    # challenge needs none: the seven tailnet-only names below have no public
    # record at all, and the two public ones are the only entries that do.
    services =
      (lib.genAttrs tailnetServices (name: {
        # headscale's `baseDomain`.
        domain = "${name}.local.${domain}";

        proxy = {
          host = "baymax";
          access = "tailnet";
        };
      }))
      // {
        # The tailnet's control server, and the reason every other entry here can
        # be addressed as `baymax`: MagicDNS resolves that name for every node that
        # joins. Selected here rather than in a group, because one host runs it.
        # This one is public, so `${domain}` needs its own Cloudflare record.
        headscale = {
          enable = true;

          # Wall-E's own addresses on the tailnet, which headscale publishes as
          # the record for every tailnet-only vhost above. It keeps a node's
          # addresses in its database rather than deriving them, so these change
          # only if Wall-E enrols from scratch.
          tailnetAddresses = [
            "100.64.0.2"
            "fd7a:115c:a1e0::2"
          ];
        };

        # Public, for phones and televisions away from the tailnet.
        pics = {
          domain = "pics.${domain}";

          proxy = {
            host = "baymax";

            # Originals and videos are uploaded through here, far past nginx's
            # 1m default.
            maxBodySize = "5g";
          };
        };

        jellyfin = {
          domain = "stream.${domain}";
          proxy.host = "baymax";
        };
      };
  };

  # These NixOS options default to true even without a desktop. They install
  # MIME, icon, sound-theme and fontconfig data that wall-e does not use.
  fonts.fontconfig.enable = false;
  xdg = {
    icons.enable = false;
    mime.enable = false;
    sounds.enable = false;
  };

  # A fact about this host's resolver, so it is set as a default: lego's
  # propagation check asks the 127.0.0.53 stub, which never sees the TXT record.
  security.acme.defaults.extraLegoFlags = [ "--dns.propagation.disable-rns" ];

  # Static, like the dotfiles repo's Hetzner host: a /32 routed via a link-local
  # gateway, and `interface` is required on both gateways under `useNetworkd`.
  networking = {
    hostName = "wall-e";

    # One NIC, so `net.ifnames=0` names it eth0, as the stock image and the
    # addresses below assume.
    usePredictableInterfaceNames = false;
    useNetworkd = true;

    defaultGateway = {
      address = "172.31.1.1";
      interface = "eth0";
    };

    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };

    # Hetzner's own resolvers, which is what the box already resolves through.
    nameservers = [
      "185.12.64.1"
      "185.12.64.2"
    ];

    interfaces.eth0 = {
      ipv4 = {
        addresses = [
          {
            address = "2.29.60.81";
            prefixLength = 32;
          }
        ];

        routes = [
          {
            address = "172.31.1.1";
            prefixLength = 32;
          }
        ];
      };

      ipv6 = {
        addresses = [
          {
            address = "2a01:4f9:c014:a051::1";
            prefixLength = 64;
          }
        ];

        routes = [
          {
            address = "fe80::1";
            prefixLength = 128;
          }
        ];
      };
    };
  };

  # A rebuild that edits any of the above would otherwise restart networkd
  # underneath the SSH session running that rebuild.
  systemd.services.systemd-networkd.stopIfChanged = false;

  # UEFI only, and the firmware reaches the bootloader through the removable
  # fallback path; ./disko.nix mounts the ESP at `/boot` for systemd-boot.
  boot.loader = {
    systemd-boot = {
      enable = true;

      # systemd-boot keeps a kernel and initrd per generation, ~100M each; ten
      # fits the 2G ESP, and leaving this null would fill it.
      configurationLimit = 10;
    };

    # Spelled out because the default has moved between nixpkgs releases.
    efi.efiSysMountPoint = "/boot";
  };

  # The disk is virtio-scsi, and neither that transport nor its HBA driver is in
  # the default initrd set, so without these stage-1 cannot mount the root fs.
  boot.initrd = {
    availableKernelModules = [
      # keep-sorted start
      "virtio_blk"
      "virtio_net"
      "virtio_pci"
      "virtio_scsi"
      # keep-sorted end
    ];

    kernelModules = [
      # keep-sorted start
      "virtio_balloon"
      "virtio_console"
      "virtio_rng"
      # keep-sorted end
    ];
  };

  # `panic=1` reboots instead of waiting for a keypress, and `console=ttyS0` last
  # is what starts the serial getty; the rest is the stock image's known-good line.
  boot.kernelParams = [
    "consoleblank=0"
    "systemd.show_status=true"
    "console=tty1"
    "console=ttyS0"
    "panic=1"
  ];

  # Both are modules here, and the sysctls below name things the kernel cannot
  # resolve until they are loaded — the assignment fails silently without these.
  boot.kernelModules = [
    # keep-sorted start
    "sch_fq"
    "tcp_bbr"
    # keep-sorted end
  ];

  boot.kernel.sysctl = {
    # This kernel defaults to cubic; BBR holds up better when a path loses
    # packets, which is every path this box serves over.
    "net.ipv4.tcp_congestion_control" = "bbr";

    # The qdisc BBR is meant to be paired with. `cake` shapes a link you own end
    # to end; this is a virtio NIC in somebody else's datacentre.
    "net.core.default_qdisc" = "fq";
  };

  # Compaction otherwise runs synchronously inside the allocation that ran out of
  # contiguous pages; `always` inflates RSS, a poor trade on a small VPS.
  boot.kernel.sysfs.kernel.mm.transparent_hugepage.defrag = "defer";

  # Hetzner's out-of-band console and password reset ride on the guest agent. On
  # a box with no other way in, that is the safety net.
  services.qemuGuest.enable = true;

  # No shared module enables sshd, and on a VPS it is the only way in; the host
  # key must exist before sops can derive this host's age recipient.
  services.openssh = {
    enable = true;
    generateHostKeys = true;

    # `keys/authorized_keys` is already installed, so these close password paths
    # (root logins included); no algorithm allowlists, which lock out new clients.
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;

      # Drop sessions that stop answering rather than holding the slot open.
      ClientAliveInterval = 60;
      ClientAliveCountMax = 5;

      # Caps unauthenticated connections per source (the DHEat DoS). 1 refused a
      # `--target-host` rebuild; the mechanism is unconfirmed, and 2 costs little.
      PerSourceMaxStartups = 2;
      PerSourceNetBlockSize = "32:128";
    };
  };

  # The only port on the public internet. `ignoreIP` stays loopback-only, so a
  # self-inflicted ban is a console login away; key auth does not fail by accident.
  services.fail2ban = {
    enable = true;
    maxretry = 5;

    bantime-increment = {
      enable = true;
      multipliers = "4 8 16 32 64 128 256 512 1024";
      maxtime = "192h";
    };
  };
}
