{
  lib,
  buildNpmPackage,
}:
buildNpmPackage {
  pname = "dashboard-frontend";
  version = "0.1.0";

  src = ./frontend;
  npmDepsHash = "sha256-b2+Y7j5lVFtMOYU44MD0z7VVgTfAJYknnGfzksp1zPU=";

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
