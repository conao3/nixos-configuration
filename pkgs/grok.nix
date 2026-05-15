{
  lib,
  stdenv,
  fetchurl,
}:
let
  version = "0.1.210";
  sources = {
    x86_64-linux = {
      url = "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-${version}-linux-x86_64";
      hash = "sha256-IowYyhIcRXfB1G/qne1DiCAs0B2MKz0zG1E3RPoGx5k=";
    };
    aarch64-linux = {
      url = "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-${version}-linux-aarch64";
      hash = "sha256-zskTsNseNf8XGV4u6MVhPhUITkj4bdK6Jxn23sb2+8I=";
    };
    aarch64-darwin = {
      url = "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-${version}-macos-aarch64";
      hash = "sha256-uQZgdxkLqdZfWGf+LOzVy2pH4toDVVroQb+iMqhWiUQ=";
    };
  };
in
stdenv.mkDerivation {
  pname = "grok";
  inherit version;

  src = fetchurl sources.${stdenv.hostPlatform.system};

  dontUnpack = true;

  installPhase = ''
    install -Dm755 $src $out/bin/grok
  '';

  meta = {
    description = "xAI Grok Build - coding agent and CLI for software engineering";
    homepage = "https://x.ai/cli";
    license = lib.licenses.unfree;
    platforms = lib.attrNames sources;
    mainProgram = "grok";
  };
}
