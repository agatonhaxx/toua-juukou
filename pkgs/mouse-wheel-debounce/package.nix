{
  lib,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "mouse-wheel-debounce";
  version = "0.1.0";

  src = ./mouse-wheel-debounce.c;

  strictDeps = true;
  dontUnpack = true;

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Wextra -std=c11 -o ${finalAttrs.pname} $src
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 ${finalAttrs.pname} $out/bin/${finalAttrs.pname}
    runHook postInstall
  '';

  meta = {
    description = "Filter encoder chatter out of a mouse wheel event stream";
    homepage = "https://github.com/eek/toua-juukou";
    mainProgram = "mouse-wheel-debounce";
    platforms = lib.platforms.linux;
  };
})
