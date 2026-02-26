{
  lib,
  buildNpmPackage,
}:
buildNpmPackage {
  pname = "dashboard-frontend";
  version = "0.1.0";

  src = ./frontend;
  npmDepsHash = "sha256-aeFTC7Ywc0xgQdcxicFuiiKyIaUSygbIUadTro/3aVU=";

  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall
    install -d "$out"
    cp -r dist/* "$out/"
    runHook postInstall
  '';

  meta = {
    description = "Vite-built React frontend for local dashboard";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
