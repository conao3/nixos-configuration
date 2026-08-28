{
  lib,
  rustPlatform,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "idea-routine";
  version = "0.1.0";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  meta = {
    description = "Inspect and update ROUTINE.md task schedules";
    homepage = "https://github.com/conao3/rust-idea-routine";
    license = lib.licenses.mit;
    mainProgram = "idea-routine";
    platforms = lib.platforms.unix;
  };
}
