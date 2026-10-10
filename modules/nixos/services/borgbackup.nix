{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.toua.services.borgbackup;

  enabledJobs = lib.filterAttrs (_: job: job.enable) cfg.jobs;
  enabledMirrors = lib.filterAttrs (_: mirror: mirror.enable) cfg.mirrors;
  hasOutbound = enabledJobs != { } || enabledMirrors != { };

  mirrorType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to mirror this repository.";
        };

        sourceRepo = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/borgbackup/${name}";
          description = "Local Borg repository to mirror while holding its lock.";
        };

        destination = lib.mkOption {
          type = lib.types.str;
          description = "rsync destination below the receiver's restricted mirror root.";
          example = "borg-mirror@baymax:mac/";
        };

        startAt = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 04:00:00";
          description = "systemd calendar expression for the mirror timer.";
        };
      };
    }
  );

  jobType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to run this job.";
      };

      repo = lib.mkOption {
        type = lib.types.str;
        description = ''
          Full repository URL. A repository served by `services.borgbackup.repos`
          at the other end is addressed as `borg@host:.`, because the forced
          command on that key has already changed into the repository directory.
        '';
        example = "borg@baymax:.";
      };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Paths to back up.";
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Patterns to exclude from the archive.";
      };

      startAt = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 02:30:00";
        description = "systemd calendar expression for the backup timer.";
      };

      preHook = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Commands to run before creating the archive.";
      };

      readWritePaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Paths the sandboxed backup job may write to.";
      };
    };
  };

  repoType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to serve this repository.";
        };

        path = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/borgbackup/${name}";
          description = "Directory the repository lives in.";
        };

        authorizedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ (lib.trim (builtins.readFile "${self}/keys/borg/${name}.pub")) ];
          defaultText = "the contents of keys/borg/<name>.pub";
          description = ''
            Public keys allowed to reach this repository. Defaults to the file
            named after the repository — the same key-per-host layout
            `keys/authorized_keys` uses for logins.
          '';
        };

        quota = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional storage quota, e.g. `100G`.";
        };

        allowSubRepos = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether clients may create repositories below `path`.";
        };
      };
    }
  );
in
{
  options.toua.services.borgbackup = {
    # Not `mkServiceOption`: borg has no address or port of its own, and every
    # connection is an ssh one.
    enable = lib.mkEnableOption "the borgbackup service";

    jobs = lib.mkOption {
      type = lib.types.attrsOf jobType;
      default = { };
      description = "Repositories this host backs up to.";
    };

    repos = lib.mkOption {
      type = lib.types.attrsOf repoType;
      default = { };
      description = "Repositories this host serves to other hosts.";
    };

    mirrors = lib.mkOption {
      type = lib.types.attrsOf mirrorType;
      default = { };
      description = "Copied with rsync while Borg holds the source lock; never written to independently.";
    };

    secretDirectory = lib.mkOption {
      type = lib.types.str;
      default = "services/borg/${config.networking.hostName}";
      defaultText = "services/borg/<networking.hostName>";
      description = "Directory below secrets containing this host's Borg credentials.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Each source host has its own SSH identity. Passphrases remain separate per
    # repository so one compromised repository does not unlock another one.
    sops.secrets =
      lib.optionalAttrs hasOutbound {
        borg-sshkey = {
          sopsFile = "${self}/secrets/${cfg.secretDirectory}/ssh-key.yaml";
          format = "binary";
          mode = "0400";
        };
      }
      // lib.mapAttrs' (
        name: _:
        lib.nameValuePair "borg-${name}-passphrase" {
          sopsFile = "${self}/secrets/${cfg.secretDirectory}/passphrase.yaml";
          format = "binary";
          mode = "0400";
        }
      ) enabledJobs
      // lib.mapAttrs' (
        name: _:
        lib.nameValuePair "borg-mirror-${name}-passphrase" {
          sopsFile = "${self}/secrets/services/borg/${name}/passphrase.yaml";
          format = "binary";
          mode = "0400";
        }
      ) enabledMirrors;

    services.borgbackup.jobs = lib.mapAttrs (
      name: jobCfg:
      lib.mkIf jobCfg.enable {
        inherit (jobCfg)
          paths
          exclude
          repo
          startAt
          preHook
          ;

        readWritePaths = jobCfg.readWritePaths ++ [ "/var/lib/borgbackup-client" ];

        environment = {
          BORG_RSH = "ssh -i ${config.sops.secrets.borg-sshkey.path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/var/lib/borgbackup-client/known_hosts";

          # A repository reached through a forced `borg serve` reports a location
          # the client did not record, which stops the job on an unanswerable prompt.
          BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes";
        };

        encryption = {
          mode = "repokey-blake2";
          passCommand = "cat ${config.sops.secrets."borg-${name}-passphrase".path}";
        };

        compression = "auto,zstd";
        extraCreateArgs = [ "--stats" ];

        prune.keep = {
          daily = 7;
          weekly = 4;
          monthly = 3;
        };

        # `services.borgbackup.repos` creates the directory but not the
        # repository inside it, and only the client side holds the passphrase.
        doInit = true;

        inhibitsSleep = true;
        persistentTimer = true;
      }
    ) cfg.jobs;

    services.borgbackup.repos = lib.mapAttrs (
      _: repoCfg:
      lib.mkIf repoCfg.enable {
        inherit (repoCfg)
          path
          authorizedKeys
          quota
          allowSubRepos
          ;
      }
    ) cfg.repos;

    systemd.services = lib.mapAttrs' (
      name: mirrorCfg:
      lib.nameValuePair "borgbackup-mirror-${name}" {
        description = "Mirror Borg repository ${name}";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        script = ''
          export BORG_PASSCOMMAND=${lib.escapeShellArg "cat ${config.sops.secrets."borg-mirror-${name}-passphrase".path}"}
          export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes

          exec ${lib.getExe config.services.borgbackup.package} with-lock \
            ${lib.escapeShellArg mirrorCfg.sourceRepo} \
            ${pkgs.rsync}/bin/rsync \
            --archive \
            --hard-links \
            --numeric-ids \
            --delete-delay \
            --delete-excluded \
            --exclude='/lock.*' \
            --rsh=${lib.escapeShellArg "ssh -i ${config.sops.secrets.borg-sshkey.path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/var/lib/borgbackup-client/known_hosts"} \
            ${lib.escapeShellArg "${mirrorCfg.sourceRepo}/"} \
            ${lib.escapeShellArg mirrorCfg.destination}
        '';

        serviceConfig = {
          Type = "oneshot";
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";
          ProtectSystem = "strict";
          ReadWritePaths = [
            mirrorCfg.sourceRepo
            "/var/lib/borgbackup-client"
          ];
          PrivateTmp = true;
        };
      }
    ) enabledMirrors;

    systemd.timers = lib.mapAttrs' (
      name: mirrorCfg:
      lib.nameValuePair "borgbackup-mirror-${name}" {
        description = "Mirror Borg repository ${name} timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = mirrorCfg.startAt;
          Persistent = true;
        };
      }
    ) enabledMirrors;

    systemd.tmpfiles.settings."10-borgbackup-client" = lib.optionalAttrs hasOutbound {
      "/var/lib/borgbackup-client".d = {
        mode = "0700";
        user = "root";
        group = "root";
      };
    };
  };
}
