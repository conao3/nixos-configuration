{
  lib,
  rustPlatform,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "agent-friction";
  version = "0.1.0";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  meta = {
    description = "Measure and compare friction in Codex JSONL sessions";
    homepage = "https://github.com/conao3/rust-agent-friction";
    license = lib.licenses.mit;
    mainProgram = "agent-friction";
    platforms = lib.platforms.unix;
  };
}
