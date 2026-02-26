{
  lib,
  buildNpmPackage,
}:
buildNpmPackage {
  pname = "ports-portal-frontend";
  version = "0.1.0";

  src = ./ports-portal-frontend;
  npmDepsHash = "sha256-LDlZML3CgqUJwz3f0QHkroZj8fe6RVfhkuP1Q04bA6s=";

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
