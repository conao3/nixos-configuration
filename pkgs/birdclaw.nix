{
  lib,
  bash,
  buildNpmPackage,
  makeWrapper,
  nodejs_25,
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

  preBuild = ''
    substituteInPlace node_modules/birdclaw/src/cli.ts \
      --replace-fail '["node_modules/vite/bin/vite.js", "dev", "--port", "3000"]' '["./server-runner.mjs"]'

    substituteInPlace node_modules/birdclaw/src/lib/bird.ts \
      --replace-quiet '"/bin/bash"' '"${bash}/bin/bash"'

    cat > node_modules/birdclaw/src/lib/seed.ts <<'SEEDEOF'
    import type { Database } from "./sqlite";

    export function seedDemoData(db: Database) {
      const accountCount = db
        .prepare("select count(*) as count from accounts")
        .get() as { count: number };
      if (accountCount.count > 0) {
        return;
      }
      const now = new Date().toISOString();
      db.prepare(
        "insert into accounts (id, name, handle, external_user_id, transport, is_default, created_at) values (?, ?, ?, ?, ?, ?, ?)"
      ).run("acct_conao3", "Conao3", "@conao_3", "238967719", "bird", 1, now);
    }
    SEEDEOF
    sed -i 's/^    //' node_modules/birdclaw/src/lib/seed.ts
  '';

  buildPhase = ''
    runHook preBuild
    ln -sfn .. node_modules/birdclaw/node_modules
    ( cd node_modules/birdclaw && ${nodejs_25}/bin/node node_modules/vite/bin/vite.js build )
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/birdclaw $out/bin
    cp -R node_modules package.json package-lock.json $out/lib/birdclaw/
    cp ${./birdclaw/server-runner.mjs} $out/lib/birdclaw/node_modules/birdclaw/server-runner.mjs

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
