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
  version = "0.6.4";

  src = fetchzip {
    name = "${pname}-${version}.tar.gz";
    url = "https://static.crates.io/crates/${pname}/${pname}-${version}.crate";
    extension = "tar.gz";
    hash = "sha256-OzzAo85sHg6rTnXanFIVl4kQiwS37r1Snt/1DXor7DM=";
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
