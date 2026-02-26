{
  lib,
  buildNpmPackage,
}:
buildNpmPackage {
  pname = "dashboard-frontend";
  version = "0.1.0";

  src = ./dashboard-frontend;
  npmDepsHash = "sha256-3wcXR5pCEaLXmhy3fbvg9u5Stdwp9GOIpdeAy2f3pHk=";

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
