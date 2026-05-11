{
  lib,
  rustPlatform,
  fetchCrate,
  makeWrapper,
  nodejs,
  google-chrome,
  procps,
}:

rustPlatform.buildRustPackage rec {
  pname = "chrome-devtools";
  version = "0.1.7";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-Piy1KkiZPO597QA7QRKtSA0/tUl7G6ropps0ld8KG8c=";
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
