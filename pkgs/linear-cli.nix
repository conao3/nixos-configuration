{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "1.10.0";
  sources = {
    x86_64-linux = {
      url = "https://github.com/schpet/linear-cli/releases/download/v${version}/linear-x86_64-unknown-linux-gnu.tar.xz";
      hash = "sha256-UZUYUkcHmh/cCM2xAxAeJrG1sdBj1fTB2n7HknjTdVg=";
    };
    aarch64-darwin = {
      url = "https://github.com/schpet/linear-cli/releases/download/v${version}/linear-aarch64-apple-darwin.tar.xz";
      hash = "sha256-gpxeAIKLgmc+UXTtFFME6pra5MElj7frWbGNSJQk7Ak=";
    };
  };
in
stdenv.mkDerivation {
  pname = "linear-cli";
  inherit version;

  src = fetchurl sources.${stdenv.hostPlatform.system};

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  sourceRoot = ".";

  installPhase = ''
    install -Dm755 linear-*/linear $out/bin/linear
  '';

  meta = {
    description = "CLI tool for Linear";
    homepage = "https://github.com/schpet/linear-cli";
    license = lib.licenses.mit;
    platforms = lib.attrNames sources;
    mainProgram = "linear";
  };
}
