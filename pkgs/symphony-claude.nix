{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm_10,
  makeWrapper,
}:
let
  pnpm = pnpm_10;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "symphony-claude";
  version = "1.0.0-unstable-2026-03-05";

  src = fetchFromGitHub {
    owner = "sapsaldog";
    repo = "claude-app-server";
    rev = "c661de12d4242da9fd0859e69c74048597769245";
    hash = "sha256-klU3ZQQ8j5rNHPe1GcCIKVZkqPZKSjkqZIOsDRYsKag=";
  };

  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 2;
    hash = "sha256-ubZIQevlRwsl1IQJ7xnout6m4Vx2W0TUK9mAZuoCJAw=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm.configHook
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/symphony-claude"
    cp -r dist package.json node_modules "$out/lib/symphony-claude/"
    makeWrapper ${nodejs}/bin/node "$out/bin/symphony-claude" \
      --add-flags "$out/lib/symphony-claude/dist/index.js"
    runHook postInstall
  '';

  meta = {
    description = "JSON-RPC 2.0 Claude Code App Server conforming to OpenAI Symphony Codex protocol";
    homepage = "https://github.com/sapsaldog/claude-app-server";
    license = lib.licenses.mit;
    mainProgram = "symphony-claude";
    platforms = lib.platforms.unix;
  };
})
