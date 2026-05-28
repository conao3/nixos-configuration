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
  version = "0.2.5";

  src = fetchzip {
    name = "${pname}-${version}.tar.gz";
    url = "https://static.crates.io/crates/${pname}/${pname}-${version}.crate";
    extension = "tar.gz";
    hash = "sha256-9/ZLyyGk0bU3SbO5x8iZwlk6np/n6Mb1uScfvTt/r7I=";
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
