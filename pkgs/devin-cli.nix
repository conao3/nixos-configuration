{
  lib,
  fetchurl,
  stdenvNoCC,
  installShellFiles,
}:
let
  version = "3000.14.30821";
  sources = {
    x86_64-linux = {
      target = "x86_64-unknown-linux";
      hash = "sha256-TcQ+PkOIus5g/iqoAQy7OZQC5ySJLXF1hFsc3vAOfds=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux";
      hash = "sha256-PeuK9rAmBg6XXtNxk24TmBgCDl3Fq7y6B83gOfRzpaU=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-Ru8addi9hRZlF54Ta345rVl9PXkTuV1n/SuI6civAGE=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "devin-cli";
  inherit version;

  src = fetchurl {
    url = "https://static.devin.ai/cli/${version}/devin-${version}-${source.target}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [ installShellFiles ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    installBin bin/devin
    installManPage share/man/man1/*.1
    mkdir -p $out/share/doc/devin-cli
    cp -r share/devin/docs/. $out/share/doc/devin-cli/
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/devin --version | grep -F ${version}
    runHook postInstallCheck
  '';

  meta = {
    description = "Cognition's Devin agent CLI";
    homepage = "https://devin.ai/cli";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "devin";
  };
}
