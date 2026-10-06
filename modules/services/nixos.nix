{ lib, ... }:
let
  inherit (import ../shared/lib.nix { inherit lib; }) importDir;
in
{
  # Every sibling is a NixOS service. `nixos.nix` names itself so that this
  # importer is not imported as a module; Darwin picks the services it wants by
  # hand in ./default.nix, because most of them do not run there.
  imports = importDir {
    dir = ./.;
    exclude = [ "nixos.nix" ];
  };
}
