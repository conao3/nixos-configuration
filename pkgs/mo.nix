{
  lib,
  fetchurl,
  stdenvNoCC,
}:
let
  version = "0.18.3";
in
stdenvNoCC.mkDerivation {
  pname = "mo";
  inherit version;

  src = fetchurl {
    url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_linux_amd64.tar.gz";
    hash = "sha256-L+vTQ4mJbM4eBFxuNGFTmVZIqotrJk6cXlkV3mFQK1c=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 mo $out/bin/mo
    runHook postInstall
  '';

  meta = {
    description = "Markdown viewer that opens .md files in a browser";
    homepage = "https://github.com/k1LoW/mo";
    license = lib.licenses.mit;
    mainProgram = "mo";
    platforms = [ "x86_64-linux" ];
  };
}
