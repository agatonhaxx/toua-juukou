final: _prev: {
  # `import` rather than `callPackage`: this is a set of pins, not a package, and
  # callPackage would decorate it with `override`/`overrideDerivation` — two
  # attributes that anything walking the set would read as extensions.
  chromium-extensions = import ./chromium-extensions.nix { inherit (final) fetchurl; };
  flow = final.callPackage ./flow/package.nix { };
  mouse-wheel-debounce = final.callPackage ./mouse-wheel-debounce/package.nix { };
}
