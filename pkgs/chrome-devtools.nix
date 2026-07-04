{
  lib,
  rustPlatform,
  fetchzip,
  makeWrapper,
  nodejs,
  google-chrome,
  procps,
  callPackage,
}:

let
  chrome-devtools-mcp = callPackage ./chrome-devtools-mcp.nix { };
in

rustPlatform.buildRustPackage rec {
  pname = "chrome-devtools";
  version = "0.4.0";

  src = fetchzip {
    name = "${pname}-${version}.tar.gz";
    url = "https://static.crates.io/crates/${pname}/${pname}-${version}.crate";
    extension = "tar.gz";
    hash = "sha256-daoMp+AMYoJ3DoF5X/gzpNNFMus0GT2VNB2VfXge+7E=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  postPatch = ''
    patchShebangs tests/fixtures
  '';

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram "$out/bin/chrome-devtools" \
      --set-default CHROME_DEVTOOLS_MCP_COMMAND ${lib.getExe chrome-devtools-mcp} \
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
