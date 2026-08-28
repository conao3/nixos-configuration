{
  lib,
  rustPlatform,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "outbound-manifest";
  version = "0.1.0";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  meta = {
    description = "Review, seal, and verify external communications";
    homepage = "https://github.com/conao3/rust-outbound-manifest";
    license = lib.licenses.mit;
    mainProgram = "outbound-manifest";
    platforms = lib.platforms.unix;
  };
}
