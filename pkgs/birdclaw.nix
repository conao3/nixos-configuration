{
  lib,
  buildNpmPackage,
  nodejs_25,
  makeWrapper,
}:

buildNpmPackage {
  pname = "birdclaw";
  version = "0.4.1";

  src = ./birdclaw;
  npmDepsHash = "sha256-AhbjwTP1fVkEThxzmr6CIzGFsOcdXravass3JQScxC8=";

  nodejs = nodejs_25;
  nativeBuildInputs = [ makeWrapper ];

  npmFlags = [ "--legacy-peer-deps" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/birdclaw $out/bin
    cp -R node_modules package.json package-lock.json $out/lib/birdclaw/
    ln -s .. $out/lib/birdclaw/node_modules/birdclaw/node_modules
    substituteInPlace $out/lib/birdclaw/node_modules/birdclaw/src/cli.ts \
      --replace-fail '["node_modules/vite/bin/vite.js", "dev", "--port", "3000"]' '["node_modules/vite/bin/vite.js", "dev", "--port", "3000", "--configLoader", "runner"]'

    substituteInPlace $out/lib/birdclaw/node_modules/birdclaw/vite.config.ts \
      --replace-fail 'const config = defineConfig({' 'const config = defineConfig({ cacheDir: (process.env.BIRDCLAW_HOME || (process.env.HOME + "/.birdclaw")) + "/.vite-cache",'

    makeWrapper ${nodejs_25}/bin/node $out/bin/birdclaw \
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
