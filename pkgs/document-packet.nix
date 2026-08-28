{
  ghostscript,
  lib,
  makeWrapper,
  rustPlatform,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "document-packet";
  version = "0.1.0";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";
  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram "$out/bin/document-packet" --prefix PATH : ${lib.makeBinPath [ ghostscript ]}
  '';

  meta = {
    description = "Build and verify reproducible PDF document packets";
    homepage = "https://github.com/conao3/rust-document-packet";
    license = lib.licenses.mit;
    mainProgram = "document-packet";
    platforms = lib.platforms.unix;
  };
}
