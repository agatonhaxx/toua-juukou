{
  lib,
  config,
  inputs,
  ...
}:
{
  programs.navi = lib.mkIf config.programs.navi.enable {
    enableFishIntegration = true;

    # The cheats live in their own repo rather than in the hive-mind notebook,
    # which is kept to `zk` knowledge. Reading them from the flake input makes
    # them read-only and pinned to a commit: to pick up an edited cheat, commit
    # in `navi-eek` and run `nix flake update navi-eek` here.
    #
    # `inputs`, not `inputs'`: the latter is for system-dependent flake outputs
    # and errors out on a `flake = false` input.
    settings.cheats.paths = [ "${inputs.navi-eek}/cheat" ];
  };
}
