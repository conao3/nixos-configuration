{
  lib,
  rustPlatform,
  fetchzip,
  makeWrapper,
  nodejs,
  google-chrome,
  procps,
}:

rustPlatform.buildRustPackage rec {
  pname = "chrome-devtools";
  version = "0.3.1";

  src = fetchzip {
    name = "${pname}-${version}.tar.gz";
    url = "https://static.crates.io/crates/${pname}/${pname}-${version}.crate";
    extension = "tar.gz";
    hash = "sha256-tkyYkiRRHiQKfGJWmIQcdfOk58Aeq+NnZJRFRGk49y8=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram "$out/bin/chrome-devtools" \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs
          google-chrome
          procps
        ]
      }
  '';

  meta = {
    description = "Profile-aware CLI for running Chrome DevTools MCP with isolated Chrome user data directories";
    homepage = "https://github.com/conao3/rust-chrome-devtools";
    license = lib.licenses.asl20;
    mainProgram = "chrome-devtools";
    platforms = lib.platforms.unix;
  };
}
