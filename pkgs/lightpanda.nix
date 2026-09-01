{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "lightpanda";
  version = "nightly-2026-09-01";

  src = fetchurl {
    url = "https://github.com/lightpanda-io/browser/releases/download/nightly/lightpanda-x86_64-linux";
    hash = "sha256-9byloXrQRt6gF+JkdfpqEfRrsK+BCdQYH7zfmEXUJE8=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/lightpanda"

    runHook postInstall
  '';

  meta = {
    description = "Headless browser designed for AI agents and automation";
    homepage = "https://github.com/lightpanda-io/browser";
    license = lib.licenses.agpl3Only;
    mainProgram = "lightpanda";
    platforms = [ "x86_64-linux" ];
  };
}
