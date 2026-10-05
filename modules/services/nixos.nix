{
  lib,
  ...
}:
let
  files = builtins.readDir ./.;
  moduleFiles = builtins.filter (
    name:
    name != "default.nix"
    && name != "nixos.nix"
    && files.${name} == "regular"
    && lib.hasSuffix ".nix" name
  ) (builtins.attrNames files);
in
{
  imports = map (name: ./. + "/${name}") moduleFiles;
}
