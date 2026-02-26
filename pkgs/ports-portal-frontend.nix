{
  lib,
  buildNpmPackage,
}:
buildNpmPackage {
  pname = "ports-portal-frontend";
  version = "0.1.0";

  src = ./ports-portal-frontend;
  npmDepsHash = "sha256-PrnNrEUH7z3IbpKpPXRfjceUxZI10GQnJjjYrMHHRpA=";

  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall
    install -d "$out"
    cp -r dist/* "$out/"
    runHook postInstall
  '';

  meta = {
    description = "Vite-built React frontend for local ports portal";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
