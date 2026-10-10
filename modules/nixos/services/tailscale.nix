{
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../../shared/lib.nix { inherit lib self; }) mkSecret;

  cfg = config.toua.services.tailscale;

  # Each host carries its own reusable preauth key under its own name, so one
  # can be revoked without touching the rest. It is only read while the node
  # enrols; afterwards the node has a key of its own, and this entry matters
  # again only if the host is reinstalled.
  preauthKey = "preauthkey-${config.networking.hostName}";
in
{
  # This lives on the NixOS side because `authKeyFile` and `extraUpFlags` are
  # NixOS options, and a definition that *names* an option is collected on both
  # platforms, whatever `mkIf` guards it. Branching on the platform in the
  # shared module instead fails too: `pkgs` is not a special argument in this
  # eval, so reading `pkgs.stdenv.hostPlatform` while the module system pushes
  # definitions down — before `config` exists — recurses.
  config = lib.mkIf (cfg.enable && cfg.loginServer != null) {
    sops.secrets.${preauthKey} = mkSecret { file = "tailscale"; };

    # `authKeyFile` is what makes this module run `tailscale up` at all, and
    # `extraUpFlags` only ever reaches that command line.
    services.tailscale = {
      authKeyFile = config.sops.secrets.${preauthKey}.path;
      extraUpFlags = [ "--login-server=${cfg.loginServer}" ];
    };
  };
}
