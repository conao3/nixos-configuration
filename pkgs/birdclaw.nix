{
  lib,
  bash,
  buildNpmPackage,
  makeWrapper,
  nodejs_26,
}:

buildNpmPackage {
  pname = "birdclaw";
  version = "0.16.3";

  src = ./birdclaw;
  npmDepsHash = "sha256-zCK/vZmUgbFh5CELEMofXEuZ2pRdL/d5hhAfLmDTCpk=";

  nodejs = nodejs_26;
  nativeBuildInputs = [ makeWrapper ];

  npmFlags = [ "--legacy-peer-deps" ];
  dontNpmBuild = true;

  preBuild = ''
    substituteInPlace node_modules/birdclaw/dist/cli/birdclaw.js \
      --replace-quiet '"/bin/bash"' '"${bash}/bin/bash"'
  '';

  buildPhase = ''
    runHook preBuild
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/birdclaw $out/bin
    cp -R node_modules package.json package-lock.json $out/lib/birdclaw/
    cp ${./birdclaw/server-runner.mjs} $out/lib/birdclaw/node_modules/birdclaw/server-runner.mjs

    makeWrapper ${nodejs_26}/bin/node $out/bin/birdclaw \
      --run 'export BIRDCLAW_HOME="''${BIRDCLAW_HOME:-$HOME/.birdclaw}"' \
      --run 'export BIRDCLAW_DISABLE_LIVE_WRITES="''${BIRDCLAW_DISABLE_LIVE_WRITES:-1}"' \
      --run 'export BIRDCLAW_BACKUP_AUTO_SYNC="''${BIRDCLAW_BACKUP_AUTO_SYNC:-0}"' \
      --add-flags $out/lib/birdclaw/node_modules/birdclaw/bin/birdclaw.mjs

    makeWrapper $out/bin/birdclaw $out/bin/birdclaw-serve \
      --add-flags serve

    runHook postInstall
  '';

  meta = {
    description = "Local Twitter memory in SQLite for archives, DMs, likes, bookmarks, and moderation";
    homepage = "https://github.com/steipete/birdclaw";
    license = lib.licenses.mit;
    mainProgram = "birdclaw";
  };
}
