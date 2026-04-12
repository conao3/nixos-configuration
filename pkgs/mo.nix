{
  lib,
  fetchurl,
  stdenvNoCC,
  unzip,
}:
let
  version = "1.0.0";
  sources = {
    x86_64-linux = {
      url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_linux_amd64.tar.gz";
      hash = "sha256-4V1aMLO+CJ7KuFqWLsMb0l+QZKQEHTc551KFLMkV3cg=";
    };
    aarch64-darwin = {
      url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_darwin_arm64.zip";
      hash = "sha256-wdoO2q96sbWdylEjfaCnlsb8bYoJLqasaukej1m+cx0=";
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
