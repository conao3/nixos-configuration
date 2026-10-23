{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
}:

stdenv.mkDerivation rec {
  pname = "lightpanda";
  version = "nightly-2026-10-23";

  src = fetchurl {
    url = "https://github.com/lightpanda-io/browser/releases/download/nightly/lightpanda-x86_64-linux";
    hash = "sha256-je0hQ/0X7toGnk14kDCxIDjZFSOuCVDs85XBpn7v5zg=";
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
