{
  lib,
  fetchurl,
  stdenvNoCC,
  unzip,
}:
let
  version = "0.18.3";
  sources = {
    x86_64-linux = {
      url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_linux_amd64.tar.gz";
      hash = "sha256-L+vTQ4mJbM4eBFxuNGFTmVZIqotrJk6cXlkV3mFQK1c=";
    };
    aarch64-darwin = {
      url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_darwin_arm64.zip";
      hash = "sha256-7GyHWC/z9yDnJPhE3cc0Js3GKu5UEjI637MZKWnKJ3s=";
    };
  };
in
stdenvNoCC.mkDerivation {
  pname = "mo";
  inherit version;

  src = fetchurl sources.${stdenvNoCC.hostPlatform.system};

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isDarwin [ unzip ];

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
    platforms = builtins.attrNames sources;
  };
}
