{
  lib,
  stdenvNoCC,
  fetchurl,
  fallbackPackage,
}:
if stdenvNoCC.hostPlatform.system != "x86_64-linux" then
  fallbackPackage
else
  stdenvNoCC.mkDerivation {
    pname = "codex-release";
    version = "0.167.2";
    src = fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v0.167.2/codex-package-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "3d77be1748d35a4bb0e7f8752cde3b11890c63338e8c599f01eafa4a59e17b3d";
    };
    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -a bin codex-package.json codex-path codex-resources "$out/"
      runHook postInstall
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      "$out/bin/codex" --version | grep -F '0.167.2'
    '';
    meta = {
      description = "Codex CLI from the official prebuilt release";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      platforms = [ "x86_64-linux" ];
    };
  }
