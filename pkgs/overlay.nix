final: _prev: {
  flow = final.callPackage ./flow/package.nix { };
  mouse-wheel-debounce = final.callPackage ./mouse-wheel-debounce/package.nix { };
}
