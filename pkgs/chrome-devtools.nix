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
  version = "0.1.0";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-944GLbpd6vON4t3IuLlIH8tcWSsgcRa/1qhWH/T3GyQ=";
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
    platforms = lib.platforms.linux;
  };
}
