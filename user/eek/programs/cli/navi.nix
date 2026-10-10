{
  lib,
  config,
  inputs,
  ...
}:
{
  programs.navi = lib.mkIf config.programs.navi.enable {
    enableFishIntegration = true;

    # Cheats come from the pinned `navi-eek` flake input, so an edited cheat
    # needs a commit there and `nix flake update navi-eek` here.

    # `inputs`, not `inputs'`: the latter is for system-dependent outputs and
    # errors out on a `flake = false` input.
    settings.cheats.paths = [ "${inputs.navi-eek}/cheat" ];
  };
}
