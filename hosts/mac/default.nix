{
  config,
  lib,
  ...
}:
let
  # The machine name and the work identity must never sit next to each other in
  # this public repository, so both live encrypted in `secrets/eek.yaml` and are
  # rendered at activation. The repository only holds the key names. sops-nix
  # only ever exposes a secret as a file on disk, which is what keeps the value
  # out of the Nix store.
  secretsFile = ../../secrets/eek.yaml;
in
{
  imports = [
    ../../user
  ];

  toua = {
    primaryUser = "Glenn.Dahl";
    users."Glenn.Dahl".homeModule = ../../user/eek;
    profiles.mac.enable = true;
    # manageUser = false;
    mac.homebrew.enable = true;

    # The only member of this group is qbittorrent, which is not wanted here.
    # The profile turns it on by default, because it follows `programs.gui.enable`.
    programs = {
      # keep-sorted start
      dev.enable = true;
      download.enable = false;
      gui.enable = true;
      k8s.enable = true;
      kiwidesk.enable = true;
      # keep-sorted end
    };
  };

  users = {
    users."Glenn.Dahl".uid = 502;
    knownUsers = [ "Glenn.Dahl" ];
  };
  # environment.systemPackages = with pkgs; [ bitwarden-cli ];

  # nix-darwin writes the hostname itself whenever these are set, and easy-hosts
  # would otherwise default `hostName` to the flake host name `mac`. Both are
  # suppressed: the activation script below is the only writer and takes the
  # name from a secret.
  networking = {
    computerName = null;
    hostName = null;
    localHostName = null;
  };

  sops = {
    secrets = {
      mac-hostname = {
        sopsFile = secretsFile;
        # sops-nix addresses nested YAML with `/`; a dot would be looked up as
        # one literal key called `work.hostname`.
        key = "work/hostname";
      };

      work-git-user-name = {
        sopsFile = secretsFile;
        key = "work/git/userName";
      };

      work-git-email = {
        sopsFile = secretsFile;
        key = "work/git/email";
      };

      work-git-default-path = {
        sopsFile = secretsFile;
        key = "work/git/defaultPath";
      };
    };

    templates = {
      # What git applies inside the work directory.
      work-git-identity = {
        owner = config.toua.primaryUser;
        mode = "400";
        content = ''
          [user]
          	name = ${config.sops.placeholder.work-git-user-name}
          	email = ${config.sops.placeholder.work-git-email}
        '';
      };

      # The `gitdir:` condition has to be a literal when git reads it, and the
      # user module is evaluated long before any secret is decrypted, so the
      # condition cannot live there without putting the work path in the repo.
      # Git's `includeIf` takes only a path, so this file carries the condition
      # and points at the identity above; the user module includes this file
      # unconditionally, and it does nothing unless a repository is under the
      # configured directory.
      work-git-include = {
        owner = config.toua.primaryUser;
        mode = "400";
        content = ''
          [includeIf "gitdir:${config.sops.placeholder.work-git-default-path}"]
          	path = ${config.sops.templates.work-git-identity.path}
        '';
      };
    };
  };

  # `mkOrder 1600` sorts this after sops-nix's own contribution to the same
  # option (it uses `mkAfter`, priority 1500), so the secret is on disk by the
  # time this runs. Without the ordering the name would only appear from the
  # second activation onwards.
  system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
    hostname_file=${lib.escapeShellArg config.sops.secrets.mac-hostname.path}
    if [ -r "$hostname_file" ]; then
      hostname="$(cat "$hostname_file")"
      /usr/sbin/scutil --set ComputerName "$hostname"
      /usr/sbin/scutil --set HostName "$hostname"
      /usr/sbin/scutil --set LocalHostName "$hostname"
    fi
  '';

  security.pam.services.sudo_local.touchIdAuth = true;
}
