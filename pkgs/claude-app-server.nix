{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
}:
let
  pnpm = pnpm_10;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "claude-app-server";
  version = "1.0.0-unstable-2026-03-05";

  src = fetchFromGitHub {
    owner = "sapsaldog";
    repo = "claude-app-server";
    rev = "c661de12d4242da9fd0859e69c74048597769245";
    hash = "sha256-klU3ZQQ8j5rNHPe1GcCIKVZkqPZKSjkqZIOsDRYsKag=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 3;
    hash = "sha256-Fx+17fXjtPJ6XggmFRyAC66LZMQRtDCgJwAeDqpMhzc=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/claude-app-server"
    cp -r dist package.json node_modules "$out/lib/claude-app-server/"
    makeWrapper ${nodejs}/bin/node "$out/bin/claude-app-server" \
      --add-flags "$out/lib/claude-app-server/dist/index.js"
    runHook postInstall
  '';

  meta = {
    description = "JSON-RPC 2.0 Claude Code App Server conforming to OpenAI Symphony Codex protocol";
    homepage = "https://github.com/sapsaldog/claude-app-server";
    license = lib.licenses.mit;
    mainProgram = "claude-app-server";
    platforms = lib.platforms.unix;
  };
})
